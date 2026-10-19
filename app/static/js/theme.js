document.addEventListener("DOMContentLoaded", function () {
    const themeToggleBtn = document.getElementById("themeToggle");
    const themeIcon = document.getElementById("themeIcon");
    const htmlElement = document.documentElement;

    if (!themeToggleBtn || !themeIcon) {
        return;
    }

    function applyTheme(theme) {
        const validTheme = theme === "dark" ? "dark" : "light";

        htmlElement.setAttribute("data-bs-theme", validTheme);
        themeIcon.className = validTheme === "dark"
            ? "bi bi-sun-fill"
            : "bi bi-moon-stars-fill";

        themeToggleBtn.setAttribute(
            "aria-label",
            validTheme === "dark"
                ? "Switch to light theme"
                : "Switch to dark theme"
        );

        themeToggleBtn.setAttribute(
            "title",
            validTheme === "dark"
                ? "Switch to light theme"
                : "Switch to dark theme"
        );
    }

    function saveTheme(theme) {
        try {
            localStorage.setItem("bookstore-theme", theme);
        } catch (error) {
            // Theme still works even if localStorage is blocked by browser policy
        }
    }

    let currentTheme =
        htmlElement.getAttribute("data-bs-theme") || "light";

    applyTheme(currentTheme);

    themeToggleBtn.addEventListener("click", function () {
        currentTheme =
            htmlElement.getAttribute("data-bs-theme") === "dark"
                ? "light"
                : "dark";

        applyTheme(currentTheme);
        saveTheme(currentTheme);
    });

    // Auto-relocate active modal directly under <body> to prevent stacking context clipping
    document.addEventListener("show.bs.modal", function (event) {
        if (event.target && event.target.parentElement !== document.body) {
            document.body.appendChild(event.target);
        }
    });
});
