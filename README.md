# init-and-push.ps1

A single-command PowerShell script to initialize local project folders as Git repositories and push them to GitHub.
Optimized for a workflow where you maintain one root “Projects” folder and each subfolder maps to a GitHub repository with the same name.

---

## ✅ One-command usage

```powershell
.\init-and-push.ps1 PROJECT-FOLDER
```

No flags required.

---

## ✨ What the script does

### If the folder is **not** a Git repository yet

1. Finds the project folder under your Projects root
2. (If `gh` is available) checks whether the GitHub repo exists
3. (If missing) creates the GitHub repo after asking **public/private** (default: public)
4. Initializes Git locally (`git init`)
5. Creates baseline files **only if missing**:
   - `.gitignore`
   - `README.md`
   - `LICENSE` (MIT)
6. Creates an initial commit
7. Pushes to GitHub via **HTTPS (SSL)** using branch `main`

### If the folder **already contains `.git`**

1. Shows a short summary
2. Prompts (default: **Yes**) to **commit & push changes**
3. Ensures `origin` exists and can optionally be updated to the expected HTTPS remote
4. Ensures the branch is `main`
5. Commits changes only if there are modifications
6. Pushes to GitHub

---

## 🔧 Defaults (hardcoded by design)

```text
Projects Root : YOUR_PROJECTS_ROOT
GitHub Owner  : YOUR_GITHUB_ACCOUNT
Default Branch: main
Remote Method : HTTPS (SSL)
```

You can change these values directly at the top of the script.

---

## ⚙️ Requirements

### Required
- Git installed and available in `PATH`

### Optional (recommended)
- GitHub CLI (`gh`) for auto-check + auto-create of repositories

Install GitHub CLI:

```powershell
winget install GitHub.cli
```

Authenticate once:

```powershell
gh auth login
```

If `gh` is not installed, the script will continue in **fail-soft mode** (repo auto-create is skipped).

---

## 🔐 Safety characteristics

- Does **not** overwrite existing `.git` repositories
- Does **not** force-push
- Creates scaffold files only if they are missing
- Uses HTTPS by default to avoid SSH key pitfalls
- Interactive prompts are used only when necessary:
  - Repo visibility only when creating a new repo
  - Commit & push confirmation if `.git` already exists
  - Optional origin update if the current remote differs

---

## 📁 Expected folder layout

```
C:\Projects\Github\
├── Project1\
├── Project2\
├── Project3\
```

Each subfolder name should match an existing GitHub repository name (or be creatable via `gh`).

---

## 🧩 Typical scenarios

### 1) New project folder → initial upload
```powershell
.\init-and-push.ps1 my-new-project
```

### 2) Existing git repo → push changes
```powershell
.\init-and-push.ps1 my-existing-project
```

---

## 📄 License

MIT License

---

## 👤 Author

**Nils Höppner**  
Infrastructure & security tooling, automation-first workflows

---

> This script is intentionally opinionated to reduce friction and mistakes.
> If you need additional flexibility (dry-run, project-type templates, logging), extend it — the structure is designed for that.
