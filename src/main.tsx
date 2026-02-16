import React from "react";
import ReactDOM from "react-dom/client";
import App from "./app/App";
import { BrowserRouter } from "react-router-dom";
import { AuthProvider } from "./app/context/AuthContext";
import "./styles/index.css";

ReactDOM.createRoot(document.getElementById("root")!).render(
  <React.StrictMode>
    <BrowserRouter>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </React.StrictMode>
);
