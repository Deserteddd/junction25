# Building Windows Executable

## Cross-Compilation Limitation

Odin does not currently support cross-compilation to Windows from macOS or Linux. The linker requires Windows-specific tools that are not available on other platforms.

## Options for Creating Windows .exe

### Option 1: Build on Windows (Recommended)

1. **Install Odin on Windows**:
   - Download from: https://odin-lang.org/
   - Follow the Windows installation instructions

2. **Copy your project** to the Windows machine

3. **Build the executable**:
   ```bash
   odin build . -out:junction25_release.exe -target:windows_amd64 -o:speed
   ```

### Option 2: Use GitHub Actions (CI/CD) ✅ READY TO USE

A GitHub Actions workflow has been created at `.github/workflows/build.yml`.

To use it:
1. Push your code to GitHub
2. Create a release tag: `git tag v1.0.0 && git push --tags`
3. GitHub Actions will automatically build for Windows, macOS, and Linux
4. Download the artifacts from the Actions tab

The workflow is already configured and ready to use!

### Option 3: Use Docker with Windows Container

If you have Docker Desktop with Windows containers enabled:

```dockerfile
FROM mcr.microsoft.com/windows/servercore:ltsc2022

# Install Odin and dependencies
# ... (setup steps)

WORKDIR /app
COPY . .

RUN odin build . -out:junction25_release.exe -target:windows_amd64 -o:speed
```

### Option 4: Share Source Code

Provide the source code and let Windows users build it themselves:

1. Share the project folder (excluding build artifacts)
2. Windows users install Odin
3. Windows users run: `odin build . -out:junction25_release.exe -target:windows_amd64 -o:speed`

## Current Status

The macOS executable is available in `junction25_distribution/junction25_release`.

For Windows users, you can:
- Share the source code
- Use GitHub Actions to automatically build Windows .exe
- Build on a Windows machine
- Provide instructions for users to build it themselves
