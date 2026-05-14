import React from "react";
import "./style.css";

const Header = () => {
  return (
    <div>
      <div className="text-center">
        <div className="pipetask-logo">⚙️</div>
        <h1 className="text-center mt-3 pipetask-title">PipeTask</h1>
        <p className="text-center pipetask-subtitle">
          Cloud-native task management, deployed with Jenkins CI/CD on Kubernetes
        </p>
        <h2 className="text-center mt-4 header-text">My Tasks</h2>
      </div>
    </div>
  );
};

export default Header;
