const { app, BrowserWindow, dialog } = require("electron");
const { spawn } = require("child_process");
const fs = require("fs");
const http = require("http");
const path = require("path");

const PORT = process.env.MOVES_PORT || "4567";
let railsProcess;
let quitting = false;
let railsEnv;
let sharedEnv;

function appRoot() {
  if (!app.isPackaged) {
    return path.resolve(__dirname, "..");
  }

  return path.join(process.resourcesPath, "app");
}

function waitForServer(url, timeoutMs = 30000) {
  const startedAt = Date.now();

  return new Promise((resolve, reject) => {
    const tryOnce = () => {
      http.get(url, (res) => {
        res.resume();
        if (res.statusCode >= 200 && res.statusCode < 500) {
          resolve();
          return;
        }
        retry();
      }).on("error", retry);
    };

    const retry = () => {
      if (Date.now() - startedAt > timeoutMs) {
        reject(new Error("Timed out waiting for Rails server"));
        return;
      }
      setTimeout(tryOnce, 500);
    };

    tryOnce();
  });
}

function runRailsTask(args) {
  return new Promise((resolve, reject) => {
    const processTask = spawn("bin/rails", args, {
      cwd: appRoot(),
      env: sharedEnv,
      stdio: "pipe"
    });

    processTask.stdout.on("data", (chunk) => {
      process.stdout.write(`[rails:${args.join("_")}] ${chunk}`);
    });

    processTask.stderr.on("data", (chunk) => {
      process.stderr.write(`[rails:${args.join("_")}] ${chunk}`);
    });

    processTask.on("exit", (code) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(new Error(`bin/rails ${args.join(" ")} exited with ${code}`));
    });
  });
}

async function startRails() {
  if (process.env.MOVES_SKIP_RAILS === "1") {
    return;
  }

  await runRailsTask(["db:prepare"]);

  railsProcess = spawn("bin/rails", ["server", "-p", PORT, "-b", "127.0.0.1"], {
    cwd: appRoot(),
    env: sharedEnv,
    stdio: "pipe"
  });

  railsProcess.stdout.on("data", (chunk) => {
    process.stdout.write(`[rails] ${chunk}`);
  });

  railsProcess.stderr.on("data", (chunk) => {
    process.stderr.write(`[rails] ${chunk}`);
  });

  railsProcess.on("exit", (code) => {
    if (!quitting && code !== 0) {
      dialog.showErrorBox("Moves server stopped", `Rails exited with code ${code}.`);
      app.quit();
    }
  });
}

function stopRails() {
  if (!railsProcess) {
    return;
  }

  try {
    railsProcess.kill("SIGTERM");
  } catch (error) {
    // no-op
  }
}

async function createWindow() {
  railsEnv = process.env.RAILS_ENV || "development";
  const storageDir = path.join(app.getPath("userData"), "storage");
  fs.mkdirSync(storageDir, { recursive: true });
  const dbPath = path.join(storageDir, `moves-${railsEnv}.sqlite3`);
  sharedEnv = {
    ...process.env,
    RAILS_ENV: railsEnv,
    MOVES_DB_PATH: dbPath
  };

  const mainWindow = new BrowserWindow({
    width: 1360,
    height: 900,
    minWidth: 1120,
    minHeight: 760,
    title: "Moves",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      sandbox: false
    }
  });

  const url = `http://127.0.0.1:${PORT}`;

  try {
    await startRails();
    await waitForServer(url);
    await mainWindow.loadURL(url);
  } catch (error) {
    dialog.showErrorBox("Moves failed to start", `${error.message}\n\nMake sure Ruby, Bundler, and Rails dependencies are installed.`);
    app.quit();
  }
}

app.whenReady().then(createWindow);

app.on("before-quit", () => {
  quitting = true;
  stopRails();
});

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});
