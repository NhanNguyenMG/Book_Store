
document.addEventListener("DOMContentLoaded", function () {
    const nutDoiGiaoDien = document.getElementById("themeToggle");
    const bieuTuong = document.getElementById("themeIcon");
    const phanTuHtml = document.documentElement;

    if (!nutDoiGiaoDien || !bieuTuong) {
        return;
    }

    function apDungGiaoDien(giaoDien) {
        const giaoDienHopLe = giaoDien === "dark" ? "dark" : "light";

        phanTuHtml.setAttribute("data-bs-theme", giaoDienHopLe);
        bieuTuong.className = giaoDienHopLe === "dark"
            ? "bi bi-sun-fill"
            : "bi bi-moon-stars-fill";

        nutDoiGiaoDien.setAttribute(
            "aria-label",
            giaoDienHopLe === "dark"
                ? "Chuyển sang giao diện sáng"
                : "Chuyển sang giao diện tối"
        );

        nutDoiGiaoDien.setAttribute(
            "title",
            giaoDienHopLe === "dark"
                ? "Chuyển sang giao diện sáng"
                : "Chuyển sang giao diện tối"
        );
    }

    function luuGiaoDien(giaoDien) {
        try {
            localStorage.setItem("bookstore-theme", giaoDien);
        } catch (error) {
            // Giao diện vẫn hoạt động nếu trình duyệt chặn localStorage.
        }
    }

    let giaoDienHienTai =
        phanTuHtml.getAttribute("data-bs-theme") || "light";

    apDungGiaoDien(giaoDienHienTai);

    nutDoiGiaoDien.addEventListener("click", function () {
        giaoDienHienTai =
            phanTuHtml.getAttribute("data-bs-theme") === "dark"
                ? "light"
                : "dark";

        apDungGiaoDien(giaoDienHienTai);
        luuGiaoDien(giaoDienHienTai);
    });

    // Tự động chuyển Modal ra trực tiếp dưới <body> khi mở
    // Giúp Modal luôn nổi lên trên backdrop ngay cả khi trang có animation / transform
    document.addEventListener("show.bs.modal", function (event) {
        if (event.target && event.target.parentElement !== document.body) {
            document.body.appendChild(event.target);
        }
    });
});
