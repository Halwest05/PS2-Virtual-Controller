document.addEventListener('DOMContentLoaded', () => {

    // === Fullscreen Initializer ===
    const startOverlay = document.getElementById('start-overlay');
    const startBtn = document.getElementById('start-btn');
    startBtn.addEventListener('click', () => {
        const docEl = document.documentElement;
        if (docEl.requestFullscreen) docEl.requestFullscreen().catch(err => console.log(err));
        else if (docEl.webkitRequestFullscreen) docEl.webkitRequestFullscreen();
        try {
            if (screen.orientation && screen.orientation.lock) screen.orientation.lock('landscape').catch(err => console.log(err));
        } catch (e) { }
        startOverlay.style.display = 'none';
        connect();
    });

    // === Layout System ===
    let layoutConfig = JSON.parse(localStorage.getItem('ps2_layout_config')) || {};
    let isEditMode = false;
    let selectedElement = null;

    const draggables = document.querySelectorAll('.draggable');
    function applySavedLayout() {
        draggables.forEach(el => {
            const id = el.getAttribute('data-id');
            const conf = layoutConfig[id];
            if (conf) {
                // Remove default transforms that might conflict with absolute left/top
                if (el.classList.contains('center-bottom') || el.classList.contains('thumb-clicks')) {
                    el.style.transform = `scale(${conf.scale || 1})`;
                } else {
                    el.style.transform = `scale(${conf.scale || 1})`;
                }
                if (conf.left !== undefined) el.style.left = conf.left + 'px';
                if (conf.top !== undefined) el.style.top = conf.top + 'px';
                el.style.bottom = 'auto'; // override default bottom rules
                el.style.right = 'auto'; // override default right rules
            } else {
                // Initialize default scale property explicitly
                el.style.transform = `scale(1)`;
            }
        });
    }
    applySavedLayout();

    function saveLayout() {
        draggables.forEach(el => {
            const id = el.getAttribute('data-id');
            const rect = el.getBoundingClientRect();
            // Need to save non-scaled Top/Left to keep it consistent
            // Since transform origin is center, getting precise pure left/top requires reading the style or bounding box.
            // BoundingClientRect gives scaled positions, so we read inline style where possible
            if (!layoutConfig[id]) layoutConfig[id] = { scale: 1 };

            let currentLeft = parseFloat(el.style.left) || el.offsetLeft;
            let currentTop = parseFloat(el.style.top) || el.offsetTop;

            layoutConfig[id].left = currentLeft;
            layoutConfig[id].top = currentTop;

            // scale is saved during slider change
        });
        localStorage.setItem('ps2_layout_config', JSON.stringify(layoutConfig));
    }

    const editToggleBtn = document.getElementById('edit-toggle-btn');
    const editControls = document.getElementById('edit-controls');
    const sizeSlider = document.getElementById('size-slider');
    const resetLayoutBtn = document.getElementById('reset-layout-btn');

    editToggleBtn.addEventListener('click', () => {
        isEditMode = !isEditMode;
        if (isEditMode) {
            document.body.classList.add('edit-mode');
            editToggleBtn.textContent = 'Save Layout';
            editToggleBtn.classList.add('active');
            editControls.style.display = 'flex';
        } else {
            document.body.classList.remove('edit-mode');
            editToggleBtn.textContent = 'Edit Layout';
            editToggleBtn.classList.remove('active');
            editControls.style.display = 'none';
            if (selectedElement) selectedElement.classList.remove('selected');
            selectedElement = null;
            saveLayout(); // Persist changes
        }
    });

    resetLayoutBtn.addEventListener('click', () => {
        localStorage.removeItem('ps2_layout_config');
        location.reload(); // Reload immediately clears memory and DOM changes
    });

    sizeSlider.addEventListener('input', (e) => {
        if (!selectedElement) return;
        const scale = parseFloat(e.target.value);
        const id = selectedElement.getAttribute('data-id');
        if (!layoutConfig[id]) layoutConfig[id] = {};
        layoutConfig[id].scale = scale;
        selectedElement.style.transform = `scale(${scale})`;
    });

    // Dragging Logic
    let dragData = null;

    document.addEventListener('touchstart', (e) => {
        if (!isEditMode) return;

        // Find which draggable we touched
        const touch = e.touches[0];
        const target = touch.target.closest('.draggable');

        if (target) {
            if (selectedElement) selectedElement.classList.remove('selected');
            selectedElement = target;
            selectedElement.classList.add('selected');

            const id = selectedElement.getAttribute('data-id');
            const conf = layoutConfig[id] || { scale: 1 };
            sizeSlider.value = conf.scale || 1;

            dragData = {
                id: touch.identifier,
                el: target,
                startX: touch.clientX,
                startY: touch.clientY,
                origLeft: target.offsetLeft,
                origTop: target.offsetTop
            };
        } else {
            // Unselect if touching empty space
            if (e.target.tagName !== 'BUTTON' && e.target.tagName !== 'INPUT' && e.target.id !== 'edit-toggle-btn') {
                if (selectedElement) selectedElement.classList.remove('selected');
                selectedElement = null;
            }
        }
    }, { passive: false });

    document.addEventListener('touchmove', (e) => {
        if (!isEditMode || !dragData) return;
        e.preventDefault();

        for (let i = 0; i < e.changedTouches.length; i++) {
            if (e.changedTouches[i].identifier === dragData.id) {
                const touch = e.changedTouches[i];
                const dx = touch.clientX - dragData.startX;
                const dy = touch.clientY - dragData.startY;

                // Override whatever CSS rules existed by forcing left/top inline styles
                dragData.el.style.left = (dragData.origLeft + dx) + 'px';
                dragData.el.style.top = (dragData.origTop + dy) + 'px';
                dragData.el.style.bottom = 'auto';
                dragData.el.style.right = 'auto';

                break;
            }
        }
    }, { passive: false });

    document.addEventListener('touchend', (e) => {
        if (dragData) {
            for (let i = 0; i < e.changedTouches.length; i++) {
                if (e.changedTouches[i].identifier === dragData.id) {
                    dragData = null;
                    break;
                }
            }
        }
    });

    // === WebSocket Connection ===
    const statusTextEl = document.getElementById('status');
    const playerIndexEl = document.getElementById('player-index');
    const wsProto = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
    const wsUrl = `${wsProto}//${window.location.host}/ws`;
    let ws = null;
    let isConnected = false;

    function connect() {
        if (isConnected) return;
        statusTextEl.textContent = "Connecting...";
        ws = new WebSocket(wsUrl);

        ws.onopen = () => {
            isConnected = true;
            statusTextEl.textContent = "Connected";
            statusTextEl.style.color = "rgba(255,255,255,0.8)";
        };

        ws.onclose = () => {
            isConnected = false;
            statusTextEl.textContent = "Disconnected...";
            statusTextEl.style.color = "red";
            playerIndexEl.textContent = "[P?]";
            setTimeout(connect, 2000);
        };

        ws.onmessage = (e) => {
            try {
                const msg = JSON.parse(e.data);
                if (msg.type === "assign_index") {
                    playerIndexEl.textContent = `[P${msg.index}]`;
                }
            } catch (err) { }
        };
    }

    function sendMsg(msg) {
        if (isConnected && ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify(msg));
        }
    }

    // === Input Logic ===
    const buttons = document.querySelectorAll('.btn:not(#btn-analog)');

    window.oncontextmenu = function (event) {
        event.preventDefault();
        event.stopPropagation();
        return false;
    };

    function pressButton(btnEl) {
        if (btnEl.classList.contains('pressed')) return;
        btnEl.classList.add('pressed');
        const btnName = btnEl.getAttribute('data-btn');
        if (btnName) {
            if (btnName === "L2" || btnName === "R2") {
                sendMsg({ type: "trigger", trigger: btnName, value: 1.0 });
            } else {
                sendMsg({ type: "button", button: btnName, pressed: true });
            }
        }
    }

    function releaseButton(btnEl) {
        if (!btnEl.classList.contains('pressed')) return;
        btnEl.classList.remove('pressed');
        const btnName = btnEl.getAttribute('data-btn');
        if (btnName) {
            if (btnName === "L2" || btnName === "R2") {
                sendMsg({ type: "trigger", trigger: btnName, value: 0.0 });
            } else {
                sendMsg({ type: "button", button: btnName, pressed: false });
            }
        }
    }

    let activeButtons = new Set();
    function handleButtonTouches(event) {
        if (isEditMode) return; // Disable game inputs while editing

        let currentlyTouchedElements = new Set();
        for (let i = 0; i < event.touches.length; i++) {
            const t = event.touches[i];
            const originEl = t.target.closest ? t.target.closest('[data-btn]') : null;
            const elementsUnder = document.elementsFromPoint(t.clientX, t.clientY);
            const currentEl = elementsUnder.find(el => el.hasAttribute("data-btn"));
            if (originEl && originEl === currentEl) {
                currentlyTouchedElements.add(originEl);
            }
        }

        currentlyTouchedElements.forEach(el => {
            if (!activeButtons.has(el)) {
                activeButtons.add(el);
                pressButton(el);
            }
        });

        activeButtons.forEach(el => {
            if (!currentlyTouchedElements.has(el)) {
                activeButtons.delete(el);
                releaseButton(el);
            }
        });

        if (currentlyTouchedElements.size > 0) {
            event.preventDefault();
        }
    }

    document.addEventListener('touchstart', handleButtonTouches, { passive: false });
    document.addEventListener('touchmove', handleButtonTouches, { passive: false });
    document.addEventListener('touchend', handleButtonTouches, { passive: false });
    document.addEventListener('touchcancel', handleButtonTouches, { passive: false });

    // === Analog Stick Logic ===
    function setupStick(baseId, capId, stickName) {
        const base = document.getElementById(baseId);
        const cap = document.getElementById(capId);
        if (!base || !cap) return;

        let activeTouchId = null;
        let isMoving = false;
        let center = { x: 0, y: 0 };
        const maxRadius = 35;

        base.addEventListener('touchstart', (e) => {
            if (isEditMode) return;
            if (activeTouchId !== null) return;
            const touch = e.changedTouches[0];
            activeTouchId = touch.identifier;
            isMoving = true;

            const rect = base.getBoundingClientRect();
            // Need accurate center even if scaled
            center = {
                x: rect.left + rect.width / 2,
                y: rect.top + rect.height / 2
            };

            e.preventDefault();
            updateStickEvent(touch);
        }, { passive: false });

        base.addEventListener('touchmove', (e) => {
            if (isEditMode) return;
            if (!isMoving) return;
            e.preventDefault();
            for (let i = 0; i < e.changedTouches.length; i++) {
                if (e.changedTouches[i].identifier === activeTouchId) {
                    updateStickEvent(e.changedTouches[i]);
                    break;
                }
            }
        }, { passive: false });

        function handleEnd(e) {
            if (!isMoving) return;
            for (let i = 0; i < e.changedTouches.length; i++) {
                if (e.changedTouches[i].identifier === activeTouchId) {
                    activeTouchId = null;
                    isMoving = false;
                    cap.style.transform = `translate(0px, 0px)`;
                    sendMsg({ type: "stick", stick: stickName, x: 0, y: 0 });
                    break;
                }
            }
        }

        base.addEventListener('touchend', handleEnd, { passive: false });
        base.addEventListener('touchcancel', handleEnd, { passive: false });

        function updateStickEvent(touch) {
            let dx = touch.clientX - center.x;
            let dy = touch.clientY - center.y;

            // Compensate for scale factor
            const parentScale = layoutConfig[baseId] ? (layoutConfig[baseId].scale || 1) : 1;

            const dist = Math.sqrt(dx * dx + dy * dy);
            const scaledMaxRadius = maxRadius * parentScale;

            if (dist > scaledMaxRadius) {
                dx = (dx / dist) * scaledMaxRadius;
                dy = (dy / dist) * scaledMaxRadius;
            }

            // Render transform is scaled inversely to match pixel travel
            cap.style.transform = `translate(${dx / parentScale}px, ${dy / parentScale}px)`;

            const nx = dx / scaledMaxRadius;
            const ny = -(dy / scaledMaxRadius);

            sendMsg({ type: "stick", stick: stickName, x: nx, y: ny });
        }
    }

    setupStick('stick-left-base', 'stick-left', 'left');
    setupStick('stick-right-base', 'stick-right', 'right');
});
