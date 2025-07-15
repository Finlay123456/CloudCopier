# 📋 Clipboard Sync System

This is a **cross-device clipboard synchronization system** that syncs clipboard content from a Windows computer to an iPad.
It consists of three main parts:

* 🖥️ A Windows app that watches the clipboard (written in C++)
* 🌐 A middleware server that relays clipboard content
* 📱 An iPad app built with Expo + React Native

Clipboard text copied on the Windows machine is instantly pushed to the cloud-based middleware server. The iPad app can then retrieve it and set it into iOS's clipboard.

---

## 🔁 Data Flow Overview

```
[Windows Clipboard Watcher (C++)]
        |
        | POST /clipboard { clipboard: "..." }
        V
[MIDDLEWARE SERVER (Node.js/Express)]
        |
        | GET /clipboard
        V
[iPad App (Expo)]
        |
        | (on tap)
        | Clipboard.setStringAsync()
        V
[iOS System Clipboard]
```

---

## 🌐 Architecture Overview

### 📁 Repository Structure

```
clipboard-sync/
├── middleware-server/        # Node.js server
│   ├── server.js
│   ├── clipboardStore.js
│   └── package.json
│
├── windows-client/           # Windows clipboard watcher (C++)
│   └── ClipboardWatcher.cpp
│
├── ipad-app/                 # iPad app (Expo + React Native)
│   ├── App.tsx
│   └── screens/ClipboardScreen.tsx
│
└── README.md
```

---

## 🌍 API Design

### POST `/clipboard`

* **Request Body:** `{ clipboard: "copied text here" }`
* **Action:** Updates the stored clipboard value.

### GET `/clipboard`

* **Response:** `{ clipboard: "most recent copied text" }`
* **Use:** Called by iPad app to display or copy clipboard text.

---

## 🧭 Components

### 1. 🖥️ Windows Clipboard Watcher (C++)

* Listens for `WM_CLIPBOARDUPDATE` via WinAPI
* On clipboard change, reads text content
* Sends a `POST /clipboard` request to the cloud middleware server

### 2. 🌐 Middleware Server (Node.js/Express)

* Deployed to a cloud provider (AWS EC2)
* Accepts clipboard updates via POST
* Serves latest clipboard via GET
* Optional enhancements: Redis caching, auth, file/image support

### 3. 📱 iPad App (Expo + React Native)

* Polls server (or uses pull-to-refresh)
* Displays clipboard content
* On user tap, uses `expo-clipboard` to copy content to iOS clipboard

---

## 🔧 Setup & Run

### Middleware Server

```
cd middleware-server
npm install
npm start
```

Default server runs on:

```
http://localhost:3000
```

### Windows Client

* Build with a C++ compiler on Windows
* Ensure it is configured to run on startup and knows the server URL

### iPad App (Expo)

```
cd ipad-app
npx expo start
```

---

## ✅ To Do (Next Iterations)

* [ ] Add Redis support for clipboard persistence
* [ ] Add support for image clipboard content
* [ ] Add WebSocket push updates
* [ ] Add authentication support
* [ ] Auto-expire clipboard entries
* [ ] Add cloud deployment instructions

---

## ✏️ Author

Finlay Cooper – 2025
