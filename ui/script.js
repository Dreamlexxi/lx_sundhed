let currentData = {
    awakeSeconds: 0,
    steps: 0,
    carMeters: 0,
    heartRate: 70,
    stepGoal: 10000
};

const RING_CIRCUMFERENCE = 326.7;

function formatAwake(seconds) {
    const min = Math.floor(seconds / 60);
    const sek = Math.floor(seconds % 60);
    return `${min} min ${sek} sek`;
}

function formatDistance(meters) {
    if (meters >= 1000) {
        return { value: (meters / 1000).toFixed(1), unit: 'km' };
    }
    return { value: Math.floor(meters).toString(), unit: 'm' };
}

function render() {
    document.getElementById('awakeValue').innerText = formatAwake(currentData.awakeSeconds);
    document.getElementById('stepsValue').innerText = Math.floor(currentData.steps).toLocaleString('da-DK');
    document.getElementById('heartValue').innerText = Math.floor(currentData.heartRate);

    const car = formatDistance(currentData.carMeters);
    document.getElementById('carValue').innerText = car.value;
    document.getElementById('carUnit').innerText = car.unit;

    const goal = currentData.stepGoal || 10000;
    const percent = Math.min(100, Math.floor((currentData.steps / goal) * 100));

    document.getElementById('goalPercent').innerText = `${percent}%`;
    document.getElementById('goalStepsValue').innerText = Math.floor(currentData.steps).toLocaleString('da-DK');
    document.getElementById('goalStepsTarget').innerText = goal.toLocaleString('da-DK');

    const ring = document.getElementById('goalRing');
    ring.style.strokeDashoffset = RING_CIRCUMFERENCE - (RING_CIRCUMFERENCE * percent) / 100;

    const goalInput = document.getElementById('goalInput');
    if (document.activeElement !== goalInput) {
        goalInput.value = goal;
    }
}

fetchNui('getData').then((res) => {
    if (res) {
        currentData = res;
        render();
    }
});

window.addEventListener('message', (e) => {
    if (e.data?.type === 'update' && e.data.data) {
        currentData = e.data.data;
        render();
    }
});

const tabButtons = document.querySelectorAll('.tab-btn');
const pages = document.querySelectorAll('.page');

tabButtons.forEach((btn) => {
    btn.onclick = () => {
        const target = btn.dataset.target;

        tabButtons.forEach((b) => b.classList.toggle('active', b === btn));
        pages.forEach((p) => p.classList.toggle('hidden', p.dataset.page !== target));
    };
});

document.getElementById('saveGoalBtn').onclick = () => {
    const goalInput = document.getElementById('goalInput');
    const goal = parseInt(goalInput.value, 10);

    if (!goal || goal < 100) return;

    fetchNui('setStepGoal', { goal }).then((res) => {
        if (res) {
            currentData = res;
            render();
            sendNotification({ title: 'Dagligt mål opdateret' });
        }
    });
};

document.getElementById('resetBtn').onclick = () => {
    setPopUp({
        title: 'Nulstil statistik',
        description: 'Er du sikker på du vil nulstille dagens statistik?',
        buttons: [
            {
                title: 'Annuller',
                color: 'red',
                cb: () => {}
            },
            {
                title: 'Nulstil',
                color: 'blue',
                cb: () => {
                    fetchNui('resetData').then((res) => {
                        if (res) {
                            currentData = res;
                            render();
                            sendNotification({ title: 'Statistik nulstillet' });
                        }
                    });
                }
            }
        ]
    });
};

function applyTheme(settings) {
    if (settings?.display?.theme) {
        document.getElementById('app').dataset.theme = settings.display.theme;
    }
}

onSettingsChange(applyTheme);
getSettings().then(applyTheme);

render();
