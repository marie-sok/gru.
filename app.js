let token = null;
let ws = null;
let currentChatId = null;

document.getElementById("login-btn").addEventListener("click", async () => {
    const phone = document.getElementById("phone").value;
    const password = document.getElementById("password").value;

    try {
        const res = await fetch("http://localhost:8081/auth/login", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ phone, password })
        });

        if (!res.ok) throw new Error("Login failed");

        token = await res.text();
        document.getElementById("login-container").classList.add("hidden");
        document.getElementById("chat-container").classList.remove("hidden");

        initWebSocket();
        loadChats();
    } catch(e) {
        alert(e.message);
    }
});

function initWebSocket() {
    ws = new WebSocket(`ws://localhost:8081/ws?userId=1&token=${token}`);

    ws.onmessage = (event) => {
        const msg = JSON.parse(event.data);
        if (msg.senderId === currentChatId || msg.receiverId === currentChatId) {
            displayMessage(msg);
        }
    };

    ws.onopen = () => console.log("WebSocket connected");
}

document.getElementById("send-btn").addEventListener("click", () => {
    const content = document.getElementById("message-input").value;
    if (!content) return;

    const msg = {
        senderId: 1,
        receiverId: currentChatId,
        content: content,
        type: "TEXT"
    };

    ws.send(JSON.stringify(msg));
    displayMessage({...msg, self: true});
    document.getElementById("message-input").value = "";
});

function displayMessage(msg) {
    const div = document.createElement("div");
    div.classList.add("message");
    div.classList.add(msg.self ? "self" : "other");
    div.textContent = msg.content;
    document.getElementById("messages").appendChild(div);
}

document.getElementById("toggle-theme").addEventListener("click", () => {
    document.body.classList.toggle("dark");
    document.body.classList.toggle("light");
});

function loadChats() {
    const chatList = document.getElementById("chat-list");
    ["Marie", "Alice", "Bob"].forEach((name, i) => {
        const btn = document.createElement("button");
        btn.textContent = name;
        btn.onclick = () => openChat(i+2);
        chatList.appendChild(btn);
    });
}

function openChat(chatId) {
    currentChatId = chatId;
    document.getElementById("chat-window").classList.remove("hidden");
    document.getElementById("messages").innerHTML = "";
}