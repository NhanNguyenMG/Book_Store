// POS Cart Management (Vanilla JavaScript)

document.addEventListener('DOMContentLoaded', function () {
    const cart = [];
    const cartTableBody = document.getElementById('cart-items-body');
    const emptyCartMsg = document.getElementById('empty-cart-msg');
    const totalAmountEl = document.getElementById('total-amount');
    const totalItemsCountEl = document.getElementById('total-items-count');
    const cartJsonInput = document.getElementById('cart_json');
    const checkoutBtn = document.getElementById('checkout-btn');
    const customerSelect = document.getElementById('customer_id');
    const customerPointsBadge = document.getElementById('customer-points-badge');
    const bookSearchInput = document.getElementById('book-search-input');
    const bookRows = document.querySelectorAll('.book-row');

    // Customer selection point preview
    if (customerSelect && customerPointsBadge) {
        customerSelect.addEventListener('change', function () {
            const selectedOpt = customerSelect.options[customerSelect.selectedIndex];
            const points = selectedOpt.getAttribute('data-points');
            if (points !== null && points !== '') {
                customerPointsBadge.textContent = 'Điểm tích lũy: ' + points + ' điểm';
                customerPointsBadge.classList.remove('d-none');
            } else {
                customerPointsBadge.classList.add('d-none');
            }
        });
    }

    // Book search filter in POS book catalog table
    if (bookSearchInput) {
        bookSearchInput.addEventListener('input', function () {
            const term = bookSearchInput.value.toLowerCase().trim();
            bookRows.forEach(row => {
                const title = row.getAttribute('data-title') || '';
                const author = row.getAttribute('data-author') || '';
                const genre = row.getAttribute('data-genre') || '';
                const match = title.includes(term) || author.includes(term) || genre.includes(term);
                row.style.display = match ? '' : 'none';
            });
        });
    }

    // Add to cart buttons
    document.querySelectorAll('.btn-add-to-cart').forEach(btn => {
        btn.addEventListener('click', function () {
            const bookId = parseInt(this.getAttribute('data-book-id'));
            const title = this.getAttribute('data-title');
            const price = parseFloat(this.getAttribute('data-price'));
            const maxStock = parseInt(this.getAttribute('data-stock'));

            addToCart(bookId, title, price, maxStock);
        });
    });

    function addToCart(bookId, title, price, maxStock) {
        const existing = cart.find(item => item.BookID === bookId);
        if (existing) {
            if (existing.Quantity < maxStock) {
                existing.Quantity += 1;
            } else {
                alert(`Sách "${title}" chỉ còn ${maxStock} cuốn trong kho.`);
                return;
            }
        } else {
            if (maxStock < 1) {
                alert(`Sách "${title}" đã hết hàng trong kho.`);
                return;
            }
            cart.push({
                BookID: bookId,
                Title: title,
                Price: price,
                MaxStock: maxStock,
                Quantity: 1
            });
        }
        renderCart();
    }

    function updateQuantity(bookId, delta) {
        const item = cart.find(i => i.BookID === bookId);
        if (!item) return;

        const newQty = item.Quantity + delta;
        if (newQty <= 0) {
            removeFromCart(bookId);
            return;
        }
        if (newQty > item.MaxStock) {
            alert(`Sách "${item.Title}" chỉ còn tối đa ${item.MaxStock} cuốn trong kho.`);
            return;
        }
        item.Quantity = newQty;
        renderCart();
    }

    function setQuantity(bookId, qty) {
        const item = cart.find(i => i.BookID === bookId);
        if (!item) return;

        let num = parseInt(qty);
        if (isNaN(num) || num < 1) num = 1;
        if (num > item.MaxStock) {
            alert(`Sách "${item.Title}" chỉ còn tối đa ${item.MaxStock} cuốn.`);
            num = item.MaxStock;
        }
        item.Quantity = num;
        renderCart();
    }

    function removeFromCart(bookId) {
        const idx = cart.findIndex(i => i.BookID === bookId);
        if (idx !== -1) {
            cart.splice(idx, 1);
        }
        renderCart();
    }

    function renderCart() {
        if (!cartTableBody) return;
        cartTableBody.innerHTML = '';

        if (cart.length === 0) {
            if (emptyCartMsg) emptyCartMsg.classList.remove('d-none');
            if (checkoutBtn) checkoutBtn.disabled = true;
            if (totalAmountEl) totalAmountEl.textContent = '0 ₫';
            if (totalItemsCountEl) totalItemsCountEl.textContent = '0';
            if (cartJsonInput) cartJsonInput.value = '[]';
            return;
        }

        if (emptyCartMsg) emptyCartMsg.classList.add('d-none');
        if (checkoutBtn) checkoutBtn.disabled = false;

        let totalAmount = 0;
        let totalItems = 0;

        cart.forEach(item => {
            const subtotal = item.Price * item.Quantity;
            totalAmount += subtotal;
            totalItems += item.Quantity;

            const tr = document.createElement('tr');
            tr.innerHTML = `
                <td class="align-middle">
                    <div class="fw-semibold text-truncate" style="max-width: 180px;" title="${item.Title}">${item.Title}</div>
                    <small class="text-muted">${item.Price.toLocaleString('vi-VN')} ₫</small>
                </td>
                <td class="align-middle text-center" style="width: 130px;">
                    <div class="input-group input-group-sm">
                        <button type="button" class="btn btn-outline-secondary btn-minus" data-id="${item.BookID}">-</button>
                        <input type="number" class="form-control text-center p-0 input-qty" data-id="${item.BookID}" value="${item.Quantity}" min="1" max="${item.MaxStock}">
                        <button type="button" class="btn btn-outline-secondary btn-plus" data-id="${item.BookID}">+</button>
                    </div>
                </td>
                <td class="align-middle text-end fw-semibold text-success" style="width: 110px;">
                    ${subtotal.toLocaleString('vi-VN')} ₫
                </td>
                <td class="align-middle text-center" style="width: 45px;">
                    <button type="button" class="btn btn-outline-danger btn-sm p-1 btn-del" data-id="${item.BookID}" title="Xóa">
                        <i class="bi bi-trash"></i>
                    </button>
                </td>
            `;
            cartTableBody.appendChild(tr);
        });

        // Attach event listeners for dynamic cart row elements
        cartTableBody.querySelectorAll('.btn-minus').forEach(btn => {
            btn.addEventListener('click', function () {
                updateQuantity(parseInt(this.getAttribute('data-id')), -1);
            });
        });
        cartTableBody.querySelectorAll('.btn-plus').forEach(btn => {
            btn.addEventListener('click', function () {
                updateQuantity(parseInt(this.getAttribute('data-id')), 1);
            });
        });
        cartTableBody.querySelectorAll('.input-qty').forEach(input => {
            input.addEventListener('change', function () {
                setQuantity(parseInt(this.getAttribute('data-id')), this.value);
            });
        });
        cartTableBody.querySelectorAll('.btn-del').forEach(btn => {
            btn.addEventListener('click', function () {
                removeFromCart(parseInt(this.getAttribute('data-id')));
            });
        });

        if (totalAmountEl) totalAmountEl.textContent = totalAmount.toLocaleString('vi-VN') + ' ₫';
        if (totalItemsCountEl) totalItemsCountEl.textContent = totalItems.toString();

        // Format payload strictly matching OPENJSON: [{"BookID": ..., "Quantity": ...}]
        const payload = cart.map(i => ({ BookID: i.BookID, Quantity: i.Quantity }));
        if (cartJsonInput) cartJsonInput.value = JSON.stringify(payload);
    }

    // Form submit validation
    const posForm = document.getElementById('pos-order-form');
    if (posForm) {
        posForm.addEventListener('submit', function (e) {
            if (cart.length === 0) {
                e.preventDefault();
                alert('Vui lòng chọn ít nhất một quyển sách vào giỏ hàng trước khi thanh toán.');
                return false;
            }
            return true;
        });
    }
});
