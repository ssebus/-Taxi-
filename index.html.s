<!DOCTYPE html>
<html lang="pl">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>System Taksówkowy z Podpisem</title>
    <style>
        :root { --primary: #f1c40f; --vip: #e74c3c; --secondary: #2c3e50; --bg: #f4f7f6; }
        body { font-family: 'Segoe UI', Tahoma, sans-serif; background: var(--bg); margin: 0; padding: 0; }
        header { background: var(--secondary); color: var(--primary); padding: 20px; text-align: center; }
        .container { max-width: 500px; margin: 20px auto; padding: 20px; }
        .card { background: white; padding: 20px; border-radius: 15px; box-shadow: 0 4px 10px rgba(0,0,0,0.1); margin-bottom: 20px; }
        label { display: block; margin: 10px 0 5px; font-weight: bold; }
        input, select { width: 100%; padding: 12px; border: 1px solid #ddd; border-radius: 8px; box-sizing: border-box; font-size: 16px; }
        button { width: 100%; padding: 15px; border: none; border-radius: 8px; font-weight: bold; cursor: pointer; transition: 0.2s; }
        .btn-order { background: var(--primary); color: var(--secondary); margin-top: 15px; }
        .btn-delete { background: #ff7675; color: white; padding: 5px 10px; width: auto; font-size: 12px; margin-top: 10px; }
        .btn-pass { background: #95a5a6; color: white; margin-top: 20px; font-size: 12px; }
        
        /* Styl Pola Podpisu */
        .signature-container { border: 2px dashed #bdc3c7; background: #fafafa; border-radius: 8px; position: relative; margin-bottom: 10px; }
        canvas { display: block; width: 100%; height: 150px; cursor: crosshair; touch-action: none; }
        .btn-clear { background: #e74c3c; color: white; padding: 5px 10px; font-size: 12px; border-radius: 4px; width: auto; margin-top: 5px; }
        
        .booking-box { border: 2px solid #eee; padding: 15px; border-radius: 10px; margin-bottom: 15px; background: #fff; }
        .tag-vip { background: var(--vip); color: white; padding: 2px 6px; border-radius: 4px; font-size: 10px; float: right; }
        .tag-normal { background: var(--primary); color: var(--secondary); padding: 2px 6px; border-radius: 4px; font-size: 10px; float: right; }
        
        .saved-signature { border: 1px solid #ddd; background: #fff; max-width: 100%; height: 80px; margin-top: 10px; display: block; }
        
        #admin-panel { display: none; }
        .footer-link { text-align: center; margin-top: 30px; color: #bdc3c7; cursor: pointer; font-size: 12px; }
    </style>
</head>
<body>

<header>
    <h1>🚖 Taxi Service</h1>
</header>

<div class="container">
    <!-- SEKCJA KLIENTA -->
    <div id="client-view" class="card">
        <h2>Zarezerwuj przejazd</h2>
        <form id="orderForm">
            <label>Wybierz usługę</label>
            <select id="type" required>
                <option value="Taksówka Zwykła">🚕 Taksówka Zwykła</option>
                <option value="Taksówka VIP">⭐ Taksówka VIP</option>
                <option value="Bus">🚌 Bus</option>
            </select>

            <label>Imię i Nazwisko</label>
            <input type="text" id="name" placeholder="Np. Jan Kowalski" required>

            <label>Kiedy (Data i Godzina)</label>
            <input type="datetime-local" id="time" required>

            <label>Skąd (Adres odbioru)</label>
            <input type="text" id="from" placeholder="Ulica i numer" required>

            <label>Dokąd jedziemy?</label>
            <input type="text" id="to" placeholder="Cel podróży" required>

            <label>Wymagany podpis klienta</label>
            <div class="signature-container">
                <canvas id="signaturePad"></canvas>
            </div>
            <button type="button" class="btn-clear" onclick="clearSignature()">Wycieraj/Popraw podpis</button>

            <button type="submit" class="btn-order">ZAMÓW PRZEJAZD</button>
        </form>
    </div>

    <!-- SEKCJA KIEROWCY (PANEL ADMINA) -->
    <div id="admin-panel" class="card">
        <h2 style="border-bottom: 2px solid var(--primary); padding-bottom: 10px;">📋 Lista Rezerwacji</h2>
        <div id="reservation-list"></div>
        
        <button onclick="changePassword()" class="btn-pass">Zmień hasło dostępu</button>
        <button onclick="logout()" style="background:#2c3e50; color:white; margin-top:10px;">Wróć do strony głównej</button>
    </div>

    <div class="footer-link" onclick="login()">🔐 Logowanie Kierowcy</div>
</div>

<script>
    let bookings = JSON.parse(localStorage.getItem('taxi_bookings_v2')) || [];
    let currentPass = localStorage.getItem('taxi_pass') || "7987";

    const orderForm = document.getElementById('orderForm');
    const resList = document.getElementById('reservation-list');
    
    // Konfiguracja rysowania podpisu
    const canvas = document.getElementById('signaturePad');
    const ctx = canvas.getContext('2d');
    let isDrawing = false;
    let hasSigned = false; // Sprawdza czy podpisano

    // Dopasowanie rozmiaru canvasu
    function resizeCanvas() {
        canvas.width = canvas.parentElement.clientWidth;
        canvas.height = 150;
        ctx.strokeStyle = "#2c3e50";
        ctx.lineWidth = 3;
        ctx.lineCap = "round";
    }
    window.addEventListener('resize', resizeCanvas);
    window.addEventListener('load', resizeCanvas);

    // Funkcje rysowania myszką i dotykiem
    function getPos(e) {
        const rect = canvas.getBoundingClientRect();
        const clientX = e.touches ? e.touches[0].clientX : e.clientX;
        const clientY = e.touches ? e.touches[0].clientY : e.clientY;
        return { x: clientX - rect.left, y: clientY - rect.top };
    }

    function startDrawing(e) {
        isDrawing = true;
        const pos = getPos(e);
        ctx.beginPath();
        ctx.moveTo(pos.x, pos.y);
    }

    function draw(e) {
        if (!isDrawing) return;
        e.preventDefault();
        const pos = getPos(e);
        ctx.lineTo(pos.x, pos.y);
        ctx.stroke();
        hasSigned = true;
    }

    function stopDrawing() { isDrawing = false; }

    canvas.addEventListener('mousedown', startDrawing);
    canvas.addEventListener('mousemove', draw);
    window.addEventListener('mouseup', stopDrawing);

    canvas.addEventListener('touchstart', startDrawing);
    canvas.addEventListener('touchmove', draw);
    window.addEventListener('touchend', stopDrawing);

    function clearSignature() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        hasSigned = false;
    }

    // OBSŁUGA ZAMÓWIENIA
    orderForm.onsubmit = function(e) {
        e.preventDefault();
        
        // Sprawdzenie czy podpis jest złożony
        if (!hasSigned) {
            alert("Błąd: Podpis jest wymagany! Proszę podpisać się w polu.");
            return;
        }

        // Zapis podpisu jako tekst (Base64)
        const signatureImg = canvas.toDataURL();
        
        const newOrder = {
            id: Date.now(),
            type: document.getElementById('type').value,
            name: document.getElementById('name').value,
            time: document.getElementById('time').value,
            from: document.getElementById('from').value,
            to: document.getElementById('to').value,
            signature: signatureImg
        };

        bookings.push(newOrder);
        localStorage.setItem('taxi_bookings_v2', JSON.stringify(bookings));
        
        alert("Dziękujemy! Rezerwacja została wysłana do kierowcy.");
        orderForm.reset();
        clearSignature();
    };

    // LOGOWANIE
    function login() {
        const pass = prompt("Podaj hasło kierowcy:");
        if (pass === currentPass) {
            document.getElementById('client-view').style.display = 'none';
            document.getElementById('admin-panel').style.display = 'block';
            renderBookings();
        } else {
            alert("Błędne hasło!");
        }
    }

    // WYŚWIETLANIE REZERWACJI W PANELU KIEROWCY
    function renderBookings() {
        resList.innerHTML = "";
        if (bookings.length === 0) {
            resList.innerHTML = "<p style='color:gray;'>Brak aktualnych rezerwacji.</p>";
            return;
        }

        bookings.forEach(order => {
            const isVip = order.type.includes("VIP");
            const box = document.createElement('div');
            box.className = 'booking-box';
            box.innerHTML = `
                <span class="${isVip ? 'tag-vip' : 'tag-normal'}">${order.type}</span>
                <strong>👤 Nazwa: ${order.name}</strong><br>
                <small>📅 Kiedy: ${order.time.replace('T', ' ')}</small><br><br>
                <div style="font-size: 14px;">
                    <b>Z:</b> ${order.from}<br>
                    <b>DO:</b> ${order.to}
                </div>
                <div style="margin-top:10px;">
                    <small style="font-weight:bold; display:block;">Podpis klienta:</small>
                    <img src="${order.signature}" class="saved-signature" alt="Podpis">
                </div>
                <button class="btn-delete" onclick="deleteOrder(${order.id})">USUŃ REZERWACJĘ</button>
            `;
            resList.appendChild(box);
        });
    }

    // USUWANIE
    function deleteOrder(id) {
        if(confirm("Czy na pewno chcesz usunąć to zlecenie?")) {
            bookings = bookings.filter(b => b.id !== id);
            localStorage.setItem('taxi_bookings_v2', JSON.stringify(bookings));
            renderBookings();
        }
    }

    // ZMIANA HASŁA
    function changePassword() {
        const old = prompt("Podaj stare hasło:");
        if(old === currentPass) {
            const newP = prompt("Podaj nowe hasło:");
            if(newP) {
                currentPass = newP;
                localStorage.setItem('taxi_pass', newP);
                alert("Hasło zostało zmienione!");
            }
        } else {
            alert("Nieprawidłowe stare hasło.");
        }
    }

    function logout() {
        document.getElementById('admin-panel').style.display = 'none';
        document.getElementById('client-view').style.display = 'block';
        setTimeout(resizeCanvas, 50); // Przeładuj rozmiar pola podpisu po powrocie
    }
</script>

</body>
</html>
