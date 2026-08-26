let token = null;
let ws = null;
let currentChatId = null;
let typingTimeout = null;

document.getElementById("login-btn").addEventListener("click", asy
nc () => {
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

        if (msg.type === "TYPING" && msg.senderId === currentChatId) {
            showTyping(true);
        } else if (msg.type === "MESSAGE" && (msg.senderId === currentChatId || msg.receiverId === currentChatId)) {
            displayMessage(msg);
        } else if (msg.type === "READ" && msg.senderId === currentChatId) {
            markMessageRead(msg.messageId);
        }
    };

    ws.onopen = () => console.log("WebSocket connected");
}

document.getElementById("message-input").addEventListener("input", () => {
    sendTypingEvent();
});

document.getElementById("send-btn").addEventListener("click", sendMessage);
document.getElementById("file-input").addEventListener("change", sendFile);

function sendMessage() {
    const content = document.getElementById("message-input").value;
    if (!content) return;

    const msg = {
        type: "MESSAGE",
        senderId: 1,
        receiverId: currentChatId,
        content: content,
        contentType: "TEXT"
    };

    ws.send(JSON.stringify(msg));
    displayMessage({...msg, self: true});
    document.getElementById("message-input").value = "";
}

function sendFile(event) {
    const file = event.target.files[0];
    if (!file) return;

    const reader = new FileReader();
    reader.onload = () => {
        const msg = {
            type: "MESSAGE",
            senderId: 1,
            receiverId: currentChatId,
            content: reader.result,
            contentType: file.type.startsWith("image/") ? "IMAGE" :
                         file.type.startsWith("video/") ? "VIDEO" : "AUDIO"
        };
        ws.send(JSON.stringify(msg));
        displayMessage({...msg, self: true});
    };
    reader.readAsDataURL(file);
}

function displayMessage(msg) {
    const div = document.createElement("div");
    div.classList.add("message");
    div.classList.add(msg.self ? "self" : "other");

    if (msg.contentType === "TEXT") div.textContent = msg.content;
    else if (msg.contentType === "IMAGE") {
        const img = document.createElement("img");
        img.src = msg.content;
        div.appendChild(img);
    } else if (msg.contentType === "VIDEO") {
        const video = document.createElement("video");
        video.src = msg.content;
        video.controls = true;
        div.appendChild(video);
    } else if (msg.contentType === "AUDIO") {
        const audio = document.createElement("audio");
        audio.src = msg.content;
        audio.controls = true;
        div.appendChild(audio);
    }

    document.getElementById("messages").appendChild(div);
    document.getElementById("messages").scrollTop = document.getElementById("messages").scrollHeight;
}

function showTyping(state) {
    const el = document.getElementById("typing-status");
    el.textContent = state ? "Typing..." : "";
    if (typingTimeout) clearTimeout(typingTimeout);
    if (state) typingTimeout = setTimeout(() => el.textContent = "", 3000);
}

function sendTypingEvent() {
    if (ws && currentChatId) {
        ws.send(JSON.stringify({type: "TYPING", senderId: 1, receiverId: currentChatId}));
    }
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

function markMessageRead(messageId) {
}