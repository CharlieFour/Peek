document.addEventListener("DOMContentLoaded", () => {
    chrome.storage.local.get("pendingLogin", (data) => {
        const login = data.pendingLogin;
        if (login) {
            document.getElementById("details").innerText =
                `Site: ${login.site}\nUsername: ${login.username}`;
        }
    });

    document.getElementById("save").addEventListener("click", () => {
        chrome.storage.local.get("pendingLogin", (data) => {
            const login = data.pendingLogin;
            if (login) {
                // Save to file
                const filePath = "C:\\Users\\Public\\login_cred.json"; // Shared location for PowerShell to read
                fetch("http://localhost:5050/save", {
                    method: "POST",
                    headers: { "Content-Type": "application/json" },
                    body: JSON.stringify(login)
                }).then(() => {
                    chrome.storage.local.set({ pendingLogin: null });
                    window.close();
                });
            }
        });
    });

    document.getElementById("cancel").addEventListener("click", () => {
        chrome.storage.local.remove("pendingLogin");
        window.close();
    });
});
