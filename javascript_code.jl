# src/routes/javascript_code.jl
module JavaScriptCode

# Основные функции загрузки карт
const MAP_FUNCTIONS = """
// ================== ОСНОВНЫЕ ФУНКЦИИ ==================
function loadMap() {
    const date = document.getElementById('dateSelect').value;
    const region = document.getElementById('regionSelect').value;
    const parameter = document.getElementById('parameterSelect').value;
    const depth = document.getElementById('depthSelect').value;
    const forecast = document.getElementById('forecastSelect').value;
    
    const forecastStr = String(forecast).padStart(3, '0');
    
    const parametersWithoutDepth = ['ice', 'mld', 'ssh'];
    let filename;
    
    if (parametersWithoutDepth.includes(parameter)) {
        filename = region + '_' + parameter + '_' + forecastStr + '.png';
    } else {
        filename = region + '_' + parameter + depth + '_' + forecastStr + '.png';
    }
    
    document.getElementById('currentMap').src = '/static/maps/' + date + '/' + filename;
}

function loadAnimation() {
    const date = document.getElementById('dateSelect').value;
    const region = document.getElementById('regionSelect').value;
    const parameter = document.getElementById('parameterSelect').value;
    const depth = document.getElementById('depthSelect').value;
    
    const parametersWithoutDepth = ['ice', 'mld', 'ssh'];
    let filename;
    
    if (parametersWithoutDepth.includes(parameter)) {
        filename = region + '_' + parameter + '_anim.gif';
    } else {
        filename = region + '_' + parameter + depth + '_anim.gif';
    }
    
    document.getElementById('currentMap').src = '/static/maps/' + date + '/' + filename;
}
"""

# Функции модальных окон
const MODAL_FUNCTIONS = """
// ================== МОДАЛЬНОЕ ОКНО КАРТЫ ==================
function openModal() {

    document.getElementById('mapModal').style.display = 'block';
    document.getElementById('modalImg').src = document.getElementById('currentMap').src;
    initSectionCanvas(); // Инициализируем canvas при открытии модального окна
}

function closeModal() {
    document.getElementById('mapModal').style.display = 'none';
    clearSectionCanvas(); // Очищаем canvas при закрытии
}

function closeGraphModal() {
    document.getElementById('graphModal').style.display = 'none';
}
"""

# Конфигурация проекций и преобразование координат
const COORDINATE_FUNCTIONS = """
// ================== КОНФИГУРАЦИЯ ПРОЕКЦИЙ И ГРАНИЦ ==================
const mapLeftM = 52;
const mapTopM = 48;
const mapRightM = 1240;
const mapBottomM = 639;

const mapLeftA = 103;
const mapTopA = 64;
const mapRightA = 692;
const mapBottomA = 668;

proj4.defs("EPSG:4326", "+proj=longlat +datum=WGS84 +no_defs");
proj4.defs("ESRI:102018", "+proj=stere +lat_0=90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs");
proj4.defs("ESRI:102021", "+proj=stere +lat_0=-90 +lon_0=0 +k=1 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs");

function getLonLat(x, y, region) {
    let mapLeft, mapTop, mapRight, mapBottom, projection;

    switch (region) {
        case 'arctic':
            mapLeft = mapLeftA;
            mapTop = mapTopA;
            mapRight = mapRightA;
            mapBottom = mapBottomA;
            projection = "ESRI:102018";
            break;
        case 'antarc':
            mapLeft = mapLeftA;
            mapTop = mapTopA;
            mapRight = mapRightA;
            mapBottom = mapBottomA;
            projection = "ESRI:102021";
            break;
        case 'wo':
        default:
            mapLeft = mapLeftM;
            mapTop = mapTopM;
            mapRight = mapRightM;
            mapBottom = mapBottomM;
            projection = "EPSG:4326";
            break;
    }

    if (x >= mapLeft && x <= mapRight && y >= mapTop && y <= mapBottom) {
        const mapX = x - mapLeft;
        const mapY = y - mapTop;

        if (region === 'wo') {
            const lon = -180 + (mapX / (mapRight - mapLeft)) * 360;
            const lat = 90 - (mapY / (mapBottom - mapTop)) * 180;
            return { lon: lon, lat: lat };
        } else {
            const centerX = (mapRight - mapLeft) / 2;
            const centerY = (mapBottom - mapTop) / 2;
            const offsetX = mapX - centerX;
            const offsetY = mapY - centerY;
            const normalizedX = offsetX / centerX;
            const normalizedY = offsetY / centerY;
            
            const meterX = normalizedX * 3329743;
            const meterY = normalizedY * 3329743;

            let point;
            if (region === 'arctic') {
                point = proj4(projection, "EPSG:4326", [meterX, meterY]);
                if (point[0] > 0) {
                    point[0] = 180 - point[0];
                } else {
                    point[0] = (point[0] + 180) * (-1);
                }
            } else if (region === 'antarc') {
                point = proj4(projection, "EPSG:4326", [meterX, meterY]);
                point[1] = -Math.abs(point[1]); 
            }
            
            return { lon: point[0], lat: point[1] };
        }
    }
    return null;
}
"""

# Отслеживание координат
const COORDINATE_TRACKING = """
// ================== ОТСЛЕЖИВАНИЕ КООРДИНАТ В МОДАЛЬНОМ ОКНЕ ==================
document.getElementById('modalImg').onmousemove = function(e) {
    const rect = this.getBoundingClientRect();
    const img = this;
    
    const relX = (e.clientX - rect.left) / rect.width;
    const relY = (e.clientY - rect.top) / rect.height;
    const absX = relX * img.naturalWidth;
    const absY = relY * img.naturalHeight;
    
    const region = document.getElementById('regionSelect').value;
    const coords = getLonLat(absX, absY, region);
    
    if (coords) {
        currentCoords = { 
            longitude: coords.lon.toFixed(2), 
            latitude: coords.lat.toFixed(2) 
        };
        document.getElementById('coordDisplay').textContent = 
            'Долгота: ' + currentCoords.longitude + '°, Широта: ' + currentCoords.latitude + '°';
    }
}
"""

# Всплывающее окно с данными
const DATA_POPUP_FUNCTIONS = """
// ================== ВСПЛЫВАЮЩЕЕ ОКНО С ДАННЫМИ ==================
function showDataPopup(data) {
    const existingPopup = document.getElementById('dataPopup');
    if (existingPopup) {
        existingPopup.remove();
    }
    
    const popup = document.createElement('div');
    popup.id = 'dataPopup';
    popup.style.cssText = 
        'position: fixed; z-index: 1002; left: 50%; top: 50%; transform: translate(-50%, -50%); ' +
        'background: rgba(255, 255, 255, 0.95); ' +
        'padding: 20px; border-radius: 12px; box-shadow: 0 5px 25px rgba(0,0,0,0.3); ' +
        'max-width: 350px; max-height: 80vh; overflow-y: auto;';
    
    popup.innerHTML = 
        '<h3 style="margin-top: 0; color: #333;">📍 Данные в точке</h3>' +
        '<p><strong>🌡️ Температура:</strong> ' + data.temperature + ' °C</p>' +
        '<p><strong>🧂 Соленость:</strong> ' + data.salinity + ' ‰</p>' +
        '<p><strong>⬆️ Компонента течения U:</strong> ' + data.u_current + ' м/с</p>' +
        '<p><strong>➡️ Компонента течения V:</strong> ' + data.v_current + ' м/с</p>' +
        '<div style="margin: 15px 0; padding: 10px; background: rgba(0,0,0,0.05); border-radius: 6px;">' +
        '<label style="display: block; margin-bottom: 8px; font-weight: bold;">🎚️ Прозрачность:</label>' +
        '<div style="display: flex; align-items: center; gap: 10px;">' +
        '<input type="range" id="opacitySlider" min="0" max="100" value="95" ' +
               'style="width: 120px; height: 6px; border-radius: 3px; background: #ddd; outline: none; flex-shrink: 0;" ' +
               'oninput="updatePopupOpacity(this.value)">' +
        '<span id="opacityValue" style="font-size: 12px; color: #666; min-width: 30px;">95%</span>' +
        '</div>' +
        '<div style="display: flex; justify-content: space-between; font-size: 10px; color: #666; margin-top: 5px; width: 120px;">' +
        '<span>Прозр.</span><span>Непрозр.</span>' +
        '</div>' +
        '</div>' +
        '<div style="margin-top: 20px; border-top: 1px solid rgba(0,0,0,0.1); padding-top: 15px;">' +
        '<h4 style="margin-bottom: 10px;">📈 Построить графики:</h4>' +
               
        '<div style="display: grid; grid-template-columns: 1fr 1fr; gap: 5px;">' +
        '<button onclick="window.showDepthProfileWithClimatology(\\'temperature\\')" style="margin: 5px; padding: 8px 12px;">Температура по глубине</button>' +
        '<button onclick="window.showDepthProfileWithClimatology(\\'salinity\\')" style="margin: 5px; padding: 8px 12px;">Соленость по глубине</button>' +
        '<button onclick="window.showDepthProfileWithClimatology(\\'currents\\')" style="margin: 5px; padding: 8px 12px;">Течения по глубине</button>' +
        '<button onclick="window.showTSDiagram()" style="margin: 5px; padding: 8px 12px;">TS-диаграмма</button>' +
        '<button onclick="window.startSectionSelection()" style="margin: 5px; padding: 8px 12px; grid-column: 1 / -1; background: #ff6b35; color: white;">📐 Построить разрез</button>' +
        '</div>' +
        '</div>' +
        '<div style="margin-top: 15px; text-align: center;">' +
        '<button onclick="closeCurrentPopup()" style="padding: 8px 16px; background: #6c757d; color: white; border: none; border-radius: 6px; cursor: pointer;">Закрыть</button>' +
        '</div>';
    
    document.body.appendChild(popup);
}

function closeCurrentPopup() {
    const popup = document.getElementById('dataPopup');
    if (popup) {
        popup.remove();
    }
}

function updatePopupOpacity(value) {
    const popup = document.getElementById('dataPopup');
    if (popup) {
        const opacity = value / 100;
        popup.style.backgroundColor = 'rgba(255, 255, 255, ' + opacity + ')';
    }
}
"""

const CLIMATOLOGY_GRAPH_FUNCTIONS = """
// ================== ФУНКЦИИ ГРАФИКОВ С КЛИМАТОЛОГИЕЙ ==================
async function showDepthProfileWithClimatology(paramType) {
    console.log("🔄 showDepthProfileWithClimatology ВЫЗВАНА!", paramType);
    
    try {
        // Получаем выбранные типы статистики
        const climatologyTypes = [];
        if (document.getElementById('climMean')?.checked) climatologyTypes.push('mean');
        if (document.getElementById('climMinMax')?.checked) climatologyTypes.push('minmax');
        if (document.getElementById('clim3Sigma')?.checked) climatologyTypes.push('3sigma');
        
        console.log("📊 Выбранные типы статистики:", climatologyTypes);
        
        const includeClimatology = climatologyTypes.length > 0;
        
        const response = await fetch('/api/plot_depth', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                parameter: paramType,
                include_climatology: includeClimatology,
                climatology_types: climatologyTypes
            })
        });
        
        const plotHtml = await response.text();
        showPlotModal(plotHtml, getGraphTitle(paramType), paramType);
        
    } catch (error) {
        alert('Ошибка построения графика: ' + error);
    }
}

// Обновляем старую функцию, чтобы она тоже поддерживала климатологию
async function showDepthProfile(paramType) {
    await showDepthProfileWithClimatology(paramType);
}

function getGraphTitle(paramType) {
    const titles = {
        'temperature': 'Температура по глубине',
        'salinity': 'Соленость по глубине', 
        'currents': 'Скорость течений по глубине'
    };
    return titles[paramType] || 'График по глубине';
}
"""

# Функции графиков
const GRAPH_FUNCTIONS = """
// ================== ФУНКЦИИ ГРАФИКОВ ==================

async function showTSDiagram() {
    try {
        const response = await fetch('/api/plot_ts', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
        
        const plotHtml = await response.text();
        showPlotModal(plotHtml);
        
    } catch (error) {
        alert('Ошибка построения TS-диаграммы: ' + error);
    }
}

function showPlotModal(htmlContent, title) {
    const graphDiv = document.getElementById('graph');
    const graphModal = document.getElementById('graphModal');
    const img = graphDiv.querySelector('img');
    if (img) {
        img.classList.add('portrait-image');
    }
    
    graphDiv.innerHTML = htmlContent;
    document.getElementById('graphTitle').textContent = title;
    graphModal.style.display = 'block';
    
    if (window.innerWidth < 768) {
        graphModal.style.width = '95vw';
        graphModal.style.height = '85vh';
    } else {
        graphModal.style.width = '400px';
        graphModal.style.height = '800px';
    }
}
"""

# Canvas функции
const CANVAS_FUNCTIONS = """
// ================== CANVAS ФУНКЦИИ ==================
function initSectionCanvas() {
    const canvas = document.getElementById('sectionCanvas');
    const modalImg = document.getElementById('modalImg');
    
    if (!canvas || !modalImg) return;
    
    // Устанавливаем размеры как у изображения
    const rect = modalImg.getBoundingClientRect();
    canvas.width = rect.width;
    canvas.height = rect.height;
    canvas.style.width = rect.width + 'px';
    canvas.style.height = rect.height + 'px';
    
    console.log("🎨 Canvas инициализирован:", canvas.width, "x", canvas.height);
}

function drawSectionLine(point1, point2) {
    console.log("🖍️ Рисование линии между точками:", point1, point2);
    
    const canvas = document.getElementById('sectionCanvas');
    if (!canvas) {
        console.error("❌ Canvas не найден");
        return;
    }
    
    const ctx = canvas.getContext('2d');
    if (!ctx) {
        console.error("❌ Контекст не получен");
        return;
    }
    
    // Очищаем Canvas (делаем полностью прозрачным)
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    
    // Показываем canvas (но он будет пустым/прозрачным)
    canvas.style.display = 'block';
    
    console.log("✅ Canvas активирован (без визуальных элементов)");
}

function clearSectionCanvas() {
    const canvas = document.getElementById('sectionCanvas');
    if (canvas) {
        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);
        canvas.style.display = 'none';  // Полностью скрываем
    }
}

function testCanvas() {
    console.log("🧪 Тестирование Canvas");
    
    const canvas = document.getElementById('sectionCanvas');
    if (!canvas) {
        alert("❌ Canvas не найден!");
        return;
    }
    
    // Показываем Canvas
    canvas.style.display = 'block';
    
    const ctx = canvas.getContext('2d');
    if (!ctx) {
        alert("❌ Не удалось получить контекст Canvas!");
        return;
    }
    
    // Тест - рисуем красный квадрат
    ctx.fillStyle = 'red';
    ctx.fillRect(50, 50, 100, 100);
    
    // Синий текст
    ctx.fillStyle = 'blue';
    ctx.font = '20px Arial';
    ctx.fillText('Canvas работает!', 50, 200);
    
    alert("✅ Canvas протестирован! Должен быть красный квадрат и синий текст.");
}
"""

# УПРОЩЕННЫЕ ФУНКЦИИ ДЛЯ РАЗРЕЗОВ
const SIMPLIFIED_SECTION_FUNCTIONS = """
// ================== УПРОЩЕННЫЕ ФУНКЦИИ ДЛЯ РАЗРЕЗОВ ==================
let sectionPoints = [];
let isSelectingSection = false;

// Упрощенная функция получения глубины
function getSelectedDepthLimit() {
    const depthInput = document.getElementById('sectionDepthInput');
    
    if (depthInput && depthInput.value.trim() !== '') {
        const depth = parseFloat(depthInput.value);
        if (!isNaN(depth) && depth > 0) {
            console.log("🎯 Заданная глубина:", depth, "м");
            return depth;
        }
    }
    
    console.log("🎯 Глубина: до дна");
    return null;
}

// Инициализация при загрузке
function setupSectionControls() {
    const depthInput = document.getElementById('sectionDepthInput');
    if (depthInput) {
        // Очищаем поле при фокусе для удобства
        depthInput.addEventListener('focus', function() {
            if (this.value === '') {
                this.placeholder = 'Например: 1000';
            }
        });
        
        depthInput.addEventListener('blur', function() {
            if (this.value === '') {
                this.placeholder = 'По умолчанию - до дна';
            }
        });
    }
}

// Запуск выбора точек разреза
function startSectionSelection() {
    console.log("🔛 Активируем режим выбора точек разреза");
    
    closeCurrentPopup();
    document.getElementById('sectionModal').style.display = 'block';
    isSelectingSection = true;
    sectionPoints = [];
    updateSectionPointsInfo();
    
    // Инициализируем Canvas
    setTimeout(initSectionCanvas, 100);

}

// Отмена выбора
function cancelSectionSelection() {
    isSelectingSection = false;
    sectionPoints = [];
    document.getElementById('sectionModal').style.display = 'none';
    clearSectionCanvas();
    
    // Очищаем поле глубины
    const depthInput = document.getElementById('sectionDepthInput');
    if (depthInput) depthInput.value = '';
}

// Подтверждение и построение разреза
async function confirmSectionSelection() {
    console.log("🎯 confirmSectionSelection вызвана");
    console.log("Количество выбранных точек:", sectionPoints.length);
    
    if (sectionPoints.length === 2) {
        try {
            console.log("✅ Отправка запроса на построение разреза");
            
            const confirmBtn = document.getElementById('confirmSectionBtn');
            confirmBtn.disabled = true;
            confirmBtn.textContent = 'Построение...';
            
            // Получаем параметры
            const parameter = document.getElementById('parameterSelect').value;
            const region = document.getElementById('regionSelect').value;
            const depth = document.getElementById('depthSelect').value;
            const date = document.getElementById('dateSelect').value;
            const forecast_hour = parseInt(document.getElementById('forecastSelect').value);
            
            // УПРОЩЕННОЕ получение глубины
            const max_depth_limit = getSelectedDepthLimit();
            
            console.log("📊 Параметры запроса:", { 
                parameter: parameter, 
                region: region,
                depth: depth,
                date: date, 
                forecast_hour: forecast_hour,
                max_depth_limit: max_depth_limit
            });
            
            const response = await fetch('/api/section_plot', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    point1: sectionPoints[0],
                    point2: sectionPoints[1],
                    parameter: parameter,
                    region: region,
                    depth: depth,
                    date: date,
                    forecast_hour: forecast_hour,
                    max_depth_limit: max_depth_limit
                })
            });
            
            if (!response.ok) {
                throw new Error('HTTP error! status: ' + response.status);
            }
            
            const plotHtml = await response.text();
            console.log("✅ HTML графика получен");
            
            // Показываем график
            showSectionPlotModal(plotHtml);
            
            // Закрываем окно выбора точек
            document.getElementById('sectionModal').style.display = 'none';
            isSelectingSection = false;
            sectionPoints = [];
            clearSectionCanvas();
            
            // Очищаем поле глубины
            const depthInput = document.getElementById('sectionDepthInput');
            if (depthInput) depthInput.value = '';
            
        } catch (error) {
            console.error('❌ Ошибка соединения:', error);
            alert('Ошибка построения разреза: ' + error);
        } finally {
            const confirmBtn = document.getElementById('confirmSectionBtn');
            confirmBtn.disabled = false;
            confirmBtn.textContent = 'Построить разрез';
        }
    } else {
        alert("❌ Сначала выберите 2 точки на карте! Выбрано: " + sectionPoints.length);
    }
}

// Обновление информации о точках
function updateSectionPointsInfo() {
    const infoDiv = document.getElementById('sectionPointsInfo');
    const confirmBtn = document.getElementById('confirmSectionBtn');
    
    if (sectionPoints.length === 0) {
        infoDiv.innerHTML = '<p style="margin: 5px 0;">📍 Точка 1: не выбрана</p><p style="margin: 5px 0;">📍 Точка 2: не выбрана</p>';
        confirmBtn.disabled = true;
        clearSectionCanvas();
    } else if (sectionPoints.length === 1) {
        infoDiv.innerHTML = '<p style="margin: 5px 0;">📍 Точка 1: ' + sectionPoints[0].lon.toFixed(2) + '°, ' + sectionPoints[0].lat.toFixed(2) + '°</p>' +
                           '<p style="margin: 5px 0;">📍 Точка 2: не выбрана</p>';
        confirmBtn.disabled = true;
        clearSectionCanvas();
    } else {
        infoDiv.innerHTML = '<p style="margin: 5px 0;">📍 Точка 1: ' + sectionPoints[0].lon.toFixed(2) + '°, ' + sectionPoints[0].lat.toFixed(2) + '°</p>' +
                           '<p style="margin: 5px 0;">📍 Точка 2: ' + sectionPoints[1].lon.toFixed(2) + '°, ' + sectionPoints[1].lat.toFixed(2) + '°</p>';
        confirmBtn.disabled = false;
        
        // Рисуем линию на карте
        drawSectionLine(sectionPoints[0], sectionPoints[1]);
    }
}
"""

# Обработчик клика по карте
const MAP_CLICK_HANDLER = """
// ================== ОБРАБОТЧИК КЛИКА ПО КАРТЕ ==================
document.getElementById('modalImg').onclick = async function(e) {
    console.log("🖱️ Клик по карте, isSelectingSection:", isSelectingSection);
    
    e.stopPropagation();
    e.preventDefault();
    
    if (isSelectingSection === true) {
        console.log("🔵 РЕЖИМ ВЫБОРА ТОЧЕК РАЗРЕЗА");
        
        if (sectionPoints.length < 2) {
            const newPoint = {
                lon: parseFloat(currentCoords.longitude),
                lat: parseFloat(currentCoords.latitude)
            };
            sectionPoints.push(newPoint);
            console.log("📌 Точка " + sectionPoints.length + " выбрана:", newPoint);
            
            updateSectionPointsInfo();
            
            if (sectionPoints.length === 2) {

            }
            return false;
        } else {
            alert("⚠️ Уже выбрано 2 точки. Нажмите 'Построить разрез' или 'Отмена'");
            return false;
        }
    }
    
    console.log("🔴 ОБЫЧНЫЙ РЕЖИМ - запрос данных точки");
    
    try {
        const response = await fetch('/api/point_data', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                longitude: currentCoords.longitude,
                latitude: currentCoords.latitude,
                forecast_hour: parseInt(document.getElementById('forecastSelect').value)
            })
        });
        
        const data = await response.json();
        if (data.error) {
            alert('Ошибка: ' + data.error);
        } else {
            showDataPopup(data);
        }
    } catch (error) {
        alert('Ошибка соединения: ' + error);
    }
    
    return false;
};
"""

# Функция для отображения графика разреза
const SECTION_PLOT_MODAL_FUNCTION = """
// Функция для отображения графика разреза
function showSectionPlotModal(htmlContent) {
    console.log("🖼️ Показ графика разреза");
    
    // Создаем модальное окно для графика разреза
    let plotModal = document.getElementById('sectionPlotModal');
    
    if (!plotModal) {
        plotModal = document.createElement('div');
        plotModal.id = 'sectionPlotModal';
        plotModal.style.cssText = 
            'display: none; position: fixed; z-index: 10002; left: 50%; top: 50%; ' +
            'transform: translate(-50%, -50%); width: 80%; max-width: 800px; height: 80%; ' +
            'max-height: 600px; background: white; border-radius: 12px; ' +
            'box-shadow: 0 10px 50px rgba(0,0,0,0.5); overflow: auto; padding: 20px;';
        
        document.body.appendChild(plotModal);
    }
    
    // Добавляем кнопку закрытия и контент
    plotModal.innerHTML = 
        '<span onclick="this.parentElement.style.display=\\'none\\'" ' +
        'style="position: absolute; top: 15px; right: 20px; font-size: 30px; font-weight: bold; cursor: pointer; color: #666;">×</span>' +
        '<div style="margin-top: 40px;">' +
        htmlContent +
        '</div>';
    
    plotModal.style.display = 'block';
}
"""

# Добавьте эту константу ПЕРЕД GLOBAL_VARIABLES
const GRAPH_UPDATE_FUNCTIONS = """
// ================== ОБНОВЛЕНИЕ ГРАФИКА С КЛИМАТОЛОГИЕЙ ==================
let currentGraphType = '';

async function updateGraphWithClimatology() {
    console.log("🔄 updateGraphWithClimatology вызвана");
    
    if (!currentGraphType) {
        console.error("❌ currentGraphType не установлен");
        return;
    }
    
    try {
        // Получаем выбранные типы статистики
        const climatologyTypes = [];
        if (document.getElementById('graphClimMean')?.checked) climatologyTypes.push('mean');
        if (document.getElementById('graphClimMinMax')?.checked) climatologyTypes.push('minmax');
        if (document.getElementById('graphClim3Sigma')?.checked) climatologyTypes.push('3sigma');
        
        console.log("📊 Обновление графика с климатологией:", {
            parameter: currentGraphType,
            climatologyTypes: climatologyTypes
        });
        
        const response = await fetch('/api/plot_depth', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ 
                parameter: currentGraphType,
                include_climatology: climatologyTypes.length > 0,
                climatology_types: climatologyTypes
            })
        });
        
        if (!response.ok) {
            throw new Error('HTTP error! status: ' + response.status);
        }
        
        const plotHtml = await response.text();
        document.getElementById('graph').innerHTML = plotHtml;
        
        console.log("✅ График обновлен с климатологией");
        
    } catch (error) {
        console.error('❌ Ошибка обновления графика:', error);
        alert('Ошибка обновления графика: ' + error);
    }
}

// Обновляем функцию показа графика
function showPlotModal(htmlContent, title, graphType = '') {
    console.log("🖼️ showPlotModal вызвана с типом:", graphType);
    
    const graphDiv = document.getElementById('graph');
    const graphModal = document.getElementById('graphModal');
    
    currentGraphType = graphType;
    
    graphDiv.innerHTML = htmlContent;
    document.getElementById('graphTitle').textContent = title;
    graphModal.style.display = 'block';
    
    // Сбрасываем переключатели при открытии
    if (document.getElementById('graphClimMean')) {
        document.getElementById('graphClimMean').checked = false;
        document.getElementById('graphClimMinMax').checked = false;
        document.getElementById('graphClim3Sigma').checked = false;
    }
    
    if (window.innerWidth < 768) {
        graphModal.style.width = '95vw';
        graphModal.style.height = '85vh';
    } else {
        graphModal.style.width = '420px';
        graphModal.style.height = '850px';
    }
}
"""

# Обновленная инициализация
const UPDATED_INITIALIZATION_CODE = """
// ================== ИНИЦИАЛИЗАЦИЯ ПРИ ЗАГРУЗКЕ ==================
setupSectionControls();  // Инициализируем управление разрезами
loadMap();  // Загружаем начальную карту

console.log("=== УПРОЩЕННЫЙ ИНТЕРФЕЙС РАЗРЕЗОВ ИНИЦИАЛИЗИРОВАН ===");
"""

# Глобальные переменные и инициализация
const GLOBAL_VARIABLES = """
// ================== ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ ==================
let currentCoords = { longitude: 0, latitude: 0 };
let currentPointData = null;

// ================== ДЕЛАЕМ ФУНКЦИИ ГЛОБАЛЬНЫМИ ==================
window.loadMap = loadMap;
window.loadAnimation = loadAnimation;
window.openModal = openModal;
window.closeModal = closeModal;
window.showDataPopup = showDataPopup;
window.closeCurrentPopup = closeCurrentPopup;
window.showDepthProfile = showDepthProfile;
window.showDepthProfileWithClimatology = showDepthProfileWithClimatology;
window.showTSDiagram = showTSDiagram;
window.showPlotModal = showPlotModal;
window.closeGraphModal = closeGraphModal;
window.updatePopupOpacity = updatePopupOpacity;
window.updateGraphWithClimatology = updateGraphWithClimatology;
window.startSectionSelection = startSectionSelection;
window.cancelSectionSelection = cancelSectionSelection;
window.confirmSectionSelection = confirmSectionSelection;
window.testCanvas = testCanvas;
window.drawSectionLine = drawSectionLine;
window.clearSectionCanvas = clearSectionCanvas;
window.initSectionCanvas = initSectionCanvas;
window.showSectionPlotModal = showSectionPlotModal;
"""

# Сборка всего JavaScript кода
const ALL_JAVASCRIPT = MAP_FUNCTIONS * MODAL_FUNCTIONS * COORDINATE_FUNCTIONS * 
                      COORDINATE_TRACKING * DATA_POPUP_FUNCTIONS * GRAPH_FUNCTIONS * 
                      CLIMATOLOGY_GRAPH_FUNCTIONS * GRAPH_UPDATE_FUNCTIONS * CANVAS_FUNCTIONS * SIMPLIFIED_SECTION_FUNCTIONS * 
                      MAP_CLICK_HANDLER * SECTION_PLOT_MODAL_FUNCTION * GLOBAL_VARIABLES * 
                      UPDATED_INITIALIZATION_CODE                      

end
