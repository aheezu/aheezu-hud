const HUD = {
    el: {},
    config: {
        defaultColors: {
            health: '#e74c3c',
            armor: '#3498db',
            hunger: '#f39c12',
            thirst: '#00bcd4',
            voice: '#2ecc71',
        },
        maxSpeed: 250,
        maxFuel: 100,
        numSegments: 11,
    },
    state: {
        savedColors: {},
        temporaryColors: {},
        progressInterval: null,
    },

    init: function() {
        this.cache();
        this.colors();
        this.binds();
        this.segments();
        this.initProgressBar();
    },

    cache: function() {
        this.el.$root = $('html');
        this.el.$saveButton = $('#save-colors');
        this.el.$cancelButton = $('#cancel-changes');
        this.el.$resetButton = $('#reset-colors');
        this.el.$settingsPanel = $('#settings-panel');
        this.el.$colorPickers = $('input[type="color"]');
        this.el.$speedSegments = $('#speed-segments');
        this.el.$fuelSegments = $('#fuel-segments');
        this.el.$hideable = $('#status-hud, #location-bar, #map-container, #fuel-gauge-bar, #speedometer-bar, #settings-panel');
        this.el.$vehicleInfo = $('#location-bar, #map-container, #fuel-gauge-bar, #speedometer-bar');
        this.el.$notifyContainer = $('#notify-container');
        
        this.el.$radioContainer = $('#radio-container');
        this.el.$playerList = $('#player-list');
        this.el.$radioChannelName = $('#radio-container .channel-name');
        this.el.$radioPlayerCount = $('#radio-container .player-count');
        this.el.$bottomHud = $('#bottom-hud');
        this.el.$bottomChannel = $('#bottom-hud #bottom-channel');
        this.el.$bottomCount = $('#bottom-hud #bottom-count');

        this.el.$progressContainer = $('#progress-container');
        this.el.$progressLabel = $('#progress-label');
        this.el.$progressAction = $('#progress-action');
        this.el.$progressBar = $('#progress-bar');
        this.el.$progressIcon = $('#progress-icon');
        this.el.$playerSsn = $('#player-ssn');
        this.el.$playerId = $('#player-id');
    },

    binds: function() {
        this.el.$saveButton.on('click', () => this.saveChanges());
        this.el.$cancelButton.on('click', () => this.cancelChanges());
        this.el.$resetButton.on('click', () => this.resetToDefaults());
        this.el.$colorPickers.on('input', (e) => this.handleColorInput(e));
        
        $(document).on('keyup', (e) => {
            if (e.key !== 'Escape') return;
            if (this.el.$settingsPanel.is(':hidden')) return;
            this.closeSettings();
        });

        window.addEventListener('message', (evt) => this.handleNuiMessage(evt));
    },

    handleNuiMessage: function(event) {
        const { action, ...data } = event.data;
        const actionMap = {
            'update': (d) => this.updateStatus(d),
            'updateHudState': (d) => this.updateHudState(d), 
            'show': () => $('#status-hud').css('display', 'flex'),
            'hide': () => this.el.$hideable.hide(),
            'toggleSettings': (d) => this.el.$settingsPanel.toggle(d.state),
            'showNotify': (d) => this.showNotification(d),
            'hideNotify': (d) => this.hideNotification(d.id),
            'showRadioList': (d) => this.updateRadioList(d),
            'showProgress': (d) => this.startProgressBar(d.data),
            'progressCancel': () => this.cancelProgressBar(false),
            'ticket': (d) => {
                this.el.$playerSsn.text(`SSN: ${d.ssn}`);
                this.el.$playerId.text(`ID: ${d.id}`);
            },
        };
        
        if (actionMap[action]) {
            actionMap[action](data);
        }
    },
    
    updateHudState: function(data) {
        this.updateStatus({ status: 'health', value: data.health });
        this.updateStatus({ status: 'armor', value: data.armor });
        this.updateStatus({ status: 'voice', value: data.voice, isTalking: data.isTalking });

        if (data.inVehicle) {
            this.el.$vehicleInfo.css('display', 'flex');
            this.el.$vehicleInfo.children().css('display', 'flex');

            $('#street-name-box').text(data.streetName ?? '');
            $('#sub-street-name-box').text(data.subStreetName ?? '');
            $('#direction-display-box').text(data.direction ?? '');
            $('#distance-container').toggle(!!data.distance).find('#distance-box').text(data.distance ?? '');
            $('#speed-value').text(String(Math.round(data.speed ?? 0)).padStart(3, '0'));
            this.updateBar(this.el.$speedSegments, data.speed, this.config.maxSpeed);
            this.updateBar(this.el.$fuelSegments, data.fuel, this.config.maxFuel);

        } else {
            if (data.phoneOpen) {
                this.el.$vehicleInfo.css('display', 'flex');
                $('#map-container').css('display', 'flex');
                $('#location-bar').css('display', 'flex');
                $('#speedometer-bar').css('display', 'none');
                $('#fuel-gauge-bar').css('display', 'none');

                $('#street-name-box').text(data.streetName ?? '');
                $('#sub-street-name-box').text(data.subStreetName ?? '');
                $('#direction-display-box').text(data.direction ?? '');
                $('#distance-container').toggle(!!data.distance).find('#distance-box').text(data.distance ?? '');
            } else {
                this.el.$vehicleInfo.css('display', 'none');
            }
        }
    },

    showNotification: function({ id, text, type = 'info', duration, spinner = false }) {
        if (!id) { id = `notify_${Math.random().toString(36).substr(2, 9)}`; }
        let $existing = this.el.$notifyContainer.find(`[data-notify-id="${id}"]`);
        if ($existing.length > 0) { $existing.find('.n-text-col').html(text); } else {
            let iconClass = 'fa-solid fa-bell';
            if (type === 'error') iconClass = 'fa-solid fa-triangle-exclamation';
            if (type === 'success') iconClass = 'fa-solid fa-check-circle';
            const spinnerHtml = spinner ? '<div class="n-spinner-col"><div class="n-spinner"></div></div>' : '';
            const $notification = $(`<div class="notification ${type}" data-notify-id="${id}"><div class="n-icon-col"><div class="n-icon-wrapper"><i class="${iconClass}"></i></div></div><div class="n-text-col">${text}</div>${spinnerHtml}</div>`);
            this.el.$notifyContainer.append($notification);
            $existing = $notification;
        }
        const existingTimer = $existing.data('timer');
        if (existingTimer) { clearTimeout(existingTimer); }
        if (duration) { const newTimer = setTimeout(() => { this.hideNotification(id); }, duration); $existing.data('timer', newTimer); }
    },

    hideNotification: function(id) {
        if (!id) return;
        const $notification = this.el.$notifyContainer.find(`[data-notify-id="${id}"]`);
        if ($notification.length > 0) { $notification.addClass('exit'); setTimeout(() => { $notification.remove(); }, 400); }
    },

    applyColors: function(colors) {
        $.each(colors, (key, value) => {
            this.el.$root.css(`--${key}-color`, value);
            $(`#${key}-color`).val(value);
        });
    },

    colors: function() {
        const stored = JSON.parse(localStorage.getItem('westside_ui') ?? '{}');
        this.state.savedColors = $.extend({}, this.config.defaultColors, stored);
        this.state.temporaryColors = { ...this.state.savedColors };
        this.applyColors(this.state.savedColors);
    },

    handleColorInput: function(event) {
        const picker = $(event.currentTarget);
        const status = picker.data('status');
        const newColor = picker.val();
        this.state.temporaryColors[status] = newColor;
        this.el.$root.css(`--${status}-color`, newColor);
    },

    saveChanges: function() {
        this.state.savedColors = { ...this.state.temporaryColors };
        localStorage.setItem('westside_ui', JSON.stringify(this.state.savedColors));
        this.closeSettings();
    },

    cancelChanges: function() {
        this.state.temporaryColors = { ...this.state.savedColors };
        this.applyColors(this.state.savedColors);
        this.closeSettings();
    },

    resetToDefaults: function() {
        this.state.temporaryColors = { ...this.config.defaultColors };
        this.applyColors(this.state.temporaryColors);
    },

    closeSettings: function() {
        $.post(`https://${GetParentResourceName()}/closeSettings`, '{}');
    },

    updateStatus: function({ status, value, isTalking }) {
        const $element = $(`#${status}`);
        if (!$element.length) return;
        if (status === 'armor') { $element.toggle(value > 0); }
        const $circle = $element.find('.progress-ring-circle');
        if ($circle.length) {
            const radius = $circle.attr('r');
            const circumference = 2 * Math.PI * radius;
            const offset = circumference - (value / 100) * circumference;
            $circle.css('stroke-dasharray', `${circumference} ${circumference}`);
            $circle.css('stroke-dashoffset', offset);
        }
        if (status === 'voice') { $element.toggleClass('talking', !!isTalking); }
    },
    
    segments: function() {
        this.generateSegmentsFor(this.el.$fuelSegments);
        this.generateSegmentsFor(this.el.$speedSegments);
    },

    generateSegmentsFor: function($container) {
        if (!$container.length) return;
        $container.empty();
        for (let i = 0; i < this.config.numSegments; i++) {
            $('<div>').addClass('bar-segment').appendTo($container);
        }
    },
    
    updateBar: function($container, value, maxValue) {
        if (!$container.length) return;
        const $segments = $container.children();
        const fillCount = Math.floor((value / maxValue) * this.config.numSegments);
        $segments.each((index, segment) => {
            $(segment).toggleClass('filled', index < fillCount);
        });
    },

    updateRadioList: function(data) {
        const { show, channel, count, players, inVehicle } = data;
        this.el.$bottomHud.toggleClass('on-foot', !inVehicle);
        this.el.$radioContainer.toggleClass('multi-user-style', count > 1);
        this.el.$radioContainer.toggle(show);
        this.el.$bottomHud.toggle(show);
        if (show) {
            this.el.$radioChannelName.text(channel);
            this.el.$radioPlayerCount.text(count);
            this.el.$bottomChannel.text(channel);
            this.el.$bottomCount.text(`${count} osób`);
            this.el.$playerList.empty();
            if (players) {
                players.forEach(player => {
                    const playerDiv = $('<div>').addClass('player-entry');
                    if (player.isTalking) { playerDiv.addClass('talking'); }
                    playerDiv.html(`<i class="speaker-icon fas fa-volume-high"></i><span class="player-details"><span class="player-badge">[${player.badge}]</span><span class="player-name">${player.name}</span></span>`);
                    this.el.$playerList.append(playerDiv);
                });
            }
        }
    },

    initProgressBar: function() {
        const segments = 10;
        this.el.$progressBar.empty();
        for (let i = 0; i < segments; i++) {
            $('<div>').addClass('progress-segment').appendTo(this.el.$progressBar);
        }
    },

    startProgressBar: function(data) {
        if (this.state.progressInterval) { clearInterval(this.state.progressInterval); }
        if (!data || !data.show) { return this.cancelProgressBar(); }
        this.el.$progressAction.text(data.label);
        this.el.$progressContainer.addClass('visible');
        let startTime = Date.now();
        let duration = data.duration;
        const totalSegments = this.el.$progressBar.children().length;
        this.state.progressInterval = setInterval(() => {
            let elapsedTime = Date.now() - startTime;
            let progress = Math.min((elapsedTime / duration) * 100, 100);
            this.el.$progressLabel.text(`Progres ${Math.floor(progress)}%`);
            let segmentsToFill = Math.ceil(progress / (100 / totalSegments));
            this.el.$progressBar.children().each(function(index) {
                $(this).toggleClass('filled', index < segmentsToFill);
            });
            if (progress >= 100) {
                clearInterval(this.state.progressInterval);
                this.state.progressInterval = null;
                $.post(`https://${GetParentResourceName()}/actionFinish`, JSON.stringify({ success: true }));
                setTimeout(() => { this.el.$progressContainer.removeClass('visible'); }, 500);
            }
        }, 50);
    },

    cancelProgressBar: function() {
        if (this.state.progressInterval) {
            clearInterval(this.state.progressInterval);
            this.state.progressInterval = null;
        }
        this.el.$progressContainer.removeClass('visible');
    },    
};

$(() => HUD.init());