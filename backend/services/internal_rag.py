import logging

logger = logging.getLogger(__name__)

try:
    from sklearn.feature_extraction.text import TfidfVectorizer
    from sklearn.metrics.pairwise import cosine_similarity
    _sklearn_available = True
except ImportError:
    _sklearn_available = False
    logger.warning("scikit-learn not available — InternalRAG will return 0.0 boost")


class InternalRAG:
    def __init__(self, db_path=None, top_k=5):
        self.top_k = top_k
        # db_path accepted for API compatibility; actual DB access goes via adaptive_store

    def retrieve_similar(self, prompt: str) -> list:
        """Return top_k most similar corpus cases using TF-IDF cosine similarity.

        Corpus = all BLOCK cases + parent-confirmed HESITATE cases (rlhf_label=1, rlhf_pending=0).
        """
        if not _sklearn_available:
            return []
        try:
            from services.adaptive_store import get_rag_corpus
            cases = get_rag_corpus(limit=500)
            if not cases:
                return []

            corpus = [c['prompt'] for c in cases]

            vectorizer = TfidfVectorizer(stop_words='english', min_df=1)
            try:
                tfidf_matrix = vectorizer.fit_transform(corpus + [prompt])
            except ValueError:
                return []

            case_vectors = tfidf_matrix[:-1]
            query_vector = tfidf_matrix[-1]

            sims = cosine_similarity(query_vector, case_vectors)[0]
            top_indices = sims.argsort()[::-1][:self.top_k]

            return [
                {
                    'prompt': cases[i]['prompt'],
                    'verdict': cases[i]['verdict'],
                    'risk_score': cases[i]['risk_score'],
                    'rlhf_label': cases[i]['rlhf_label'],
                    'similarity_score': float(sims[i]),
                }
                for i in top_indices
            ]
        except Exception as e:
            logger.warning("InternalRAG.retrieve_similar error: %s", e)
            return []

    def compute_rag_boost(self, prompt: str) -> float:
        """Return a risk boost [0.0, 0.20] based on similarity to corpus cases."""
        try:
            cases = self.retrieve_similar(prompt)
            if not cases:
                return 0.0
            boost = sum(
                c['similarity_score'] * c['risk_score'] for c in cases
            ) / self.top_k
            return min(boost, 0.20)
        except Exception as e:
            logger.warning("InternalRAG.compute_rag_boost error: %s", e)
            return 0.0

    def get_context_summary(self, prompt: str) -> dict:
        """Return explainability summary used by _defense_check and admin dashboard."""
        _empty = {
            'cases_found': 0,
            'top_similarity': 0.0,
            'avg_risk_of_similar': 0.0,
            'rag_boost': 0.0,
            'top_cases': [],
            'corpus_breakdown': {'block_cases': 0, 'hesitate_confirmed': 0},
        }
        try:
            # Corpus breakdown (full corpus, not just top_k)
            from services.adaptive_store import get_rag_corpus
            full_corpus = get_rag_corpus(limit=500)
            block_cases      = sum(1 for c in full_corpus if c['verdict'] == 'BLOCK')
            hesitate_confirmed = sum(1 for c in full_corpus if c['verdict'] == 'HESITATE')

            cases = self.retrieve_similar(prompt)
            if not cases:
                return {**_empty, 'corpus_breakdown': {
                    'block_cases': block_cases,
                    'hesitate_confirmed': hesitate_confirmed,
                }}

            boost = min(
                sum(c['similarity_score'] * c['risk_score'] for c in cases) / self.top_k,
                0.20,
            )
            top_similarity = max(c['similarity_score'] for c in cases)
            avg_risk = sum(c['risk_score'] for c in cases) / len(cases)

            return {
                'cases_found': len(cases),
                'top_similarity': round(top_similarity, 3),
                'avg_risk_of_similar': round(avg_risk, 3),
                'rag_boost': round(boost, 3),
                'top_cases': cases[:3],
                'corpus_breakdown': {
                    'block_cases': block_cases,
                    'hesitate_confirmed': hesitate_confirmed,
                },
            }
        except Exception as e:
            logger.warning("InternalRAG.get_context_summary error: %s", e)
            return _empty
