# src/routes/html_templates.jl
module HTMLTemplates

using ..CSSStyles

const COMPLETE_HTML_TEMPLATE = """
<!DOCTYPE html>
<html>
<head>
    <title>NEMO Ocean Model Viewer</title>
    <meta charset="utf-8">
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate">
    <meta http-equiv="Pragma" content="no-cache">
    <meta http-equiv="Expires" content="0">
    <link rel="icon" href="data:;base64,iVBORw0KGgo=">
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/proj4js/2.8.0/proj4.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chartjs-plugin-zoom@1.2.1/dist/chartjs-plugin-zoom.min.js"></script>
    <style>
        $(ALL_STYLES)
    </style>            
</head>
<body>
    <div class="container">
        <h1>🌊 NEMO Ocean Data Viewer</h1>
        <p><strong>Последняя доступная дата: %LATEST_DATE%</strong></p>
        
        <!-- Модальное окно карты -->
        <div id="mapModal" class="modal" style="display: none;">
            <span class="close" onclick="closeModal()" style="position: absolute; top: 20px; right: 35px; color: #f1f1f1; font-size: 40px; font-weight: bold; cursor: pointer;">&times;</span>
            <img class="modal-content" id="modalImg" style="margin: auto; display: block; max-width: 90%; max-height: 80%; margin-top: 2%;">
            <canvas id="sectionCanvas" style="position: absolute; top: 0; left: 0; width: 100%; height: 100%; pointer-events: none; z-index: 1000; display: none;"></canvas>
            <div id="coordDisplay" style="position: absolute; top: 20px; left: 20px; color: white; background-color: rgba(0,0,0,0.7); padding: 12px 16px; border-radius: 8px;">Долгота: -, Широта: -</div>
        </div>
            
        <div class="main-content">
            <div class="map-container">
                <img id="currentMap" class="map-preview" src="/static/sample_map.png" onclick="openModal()">
            </div>
            
            <div class="controls-container">
                <div class="form-group">
                    <label for="dateSelect">Дата:</label>
                    <input type="date" id="dateSelect" value="%LATEST_DATE%">
                </div>
                <div class="form-group">
                    <label for="regionSelect">Регион:</label>
                    <select id="regionSelect">
                        <option value="arctic">Арктика</option>
                        <option value="antarc">Антарктика</option>
                        <option value="wo">Мировой океан</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="parameterSelect">Параметр:</label>
                    <select id="parameterSelect">
                        <option value="Tz">Температура</option>
                        <option value="Sz">Соленость</option>
                        <option value="UVz">Течения</option>
                        <option value="ice">Лед</option>
                        <option value="ssh">Уровень моря</option>
                        <option value="mld">Перемешанный слой</option>
                    </select>
                </div>
                <div class="form-group">
                    <label for="depthSelect">Горизонт:</label>
                    <select id="depthSelect">
                        <option value="0p5">Поверхность (0.5 м)</option>
                        <option value="97">97 м</option>
                        <option value="1046">1046 м</option>
                    </select>
                </div>
                
                
                <div class="form-group">
                    <label for="forecastSelect">Время прогноза:</label>
                    <select id="forecastSelect">
                        <option value="0">Анализ</option>
                        <option value="24">+24 часа</option>
                        <option value="48">+48 часов</option>
                        <option value="72">+72 часа</option>
                        <option value="96">+96 часов</option>
                        <option value="120">+120 часов</option>
                        <option value="144">+144 часа</option>
                        <option value="168">+168 часа</option>
                        <option value="192">+192 часа</option>
                        <option value="216">+216 часов</option>
                        <option value="240">+240 часов</option>
                    </select>
                </div>
                
                <button id="loadMapBtn" onclick="loadMap()">Загрузить карту</button>
                <button id="loadAnimationBtn" onclick="loadAnimation()">Анимация</button>
            </div>
        </div>
    </div>
    
<!-- Окно для графиков с климатологией -->
<div id="graphModal" style="display: none; position: fixed; z-index: 10000; left: 50%; top: 50%; transform: translate(-50%, -50%); width: 420px; height: 850px; max-width: 90vw; max-height: 90vh; background: white; border-radius: 12px; box-shadow: 0 10px 50px rgba(0,0,0,0.5); overflow: auto;">
    <div style="padding: 20px; height: 100%; display: flex; flex-direction: column;">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 15px;">
            <h3 id="graphTitle" style="margin: 0; font-size: 18px;"></h3>
            <span onclick="closeGraphModal()" style="cursor: pointer; font-size: 24px; font-weight: bold;">&times;</span>
        </div>
        
        <!-- ПЕРЕКЛЮЧАТЕЛИ СТАТИСТИКИ В ГРАФИКЕ -->
        <div class="climatology-controls">
            <span class="climatology-title">📊 Климатические профили:</span>
            <div class="climatology-options">
                <label class="climatology-option">
                    <input type="checkbox" id="graphClimMean" value="mean">
                    Среднее
                </label>
                <label class="climatology-option">
                    <input type="checkbox" id="graphClimMinMax" value="minmax">
                    Min/Max
                </label>
                <label class="climatology-option">
                    <input type="checkbox" id="graphClim3Sigma" value="3sigma">
                    ±3σ
                </label>
            </div>
        </div>
        
        <div id="graph" style="width: 100%; flex-grow: 1; min-height: 0; margin-top: 10px;"></div>
        
        <!-- Кнопка обновления графика -->
        <button onclick="updateGraphWithClimatology()" style="margin-top: 15px; padding: 10px; background: #007bff; color: white; border: none; border-radius: 6px; cursor: pointer;">
            Обновить график с климатологией
        </button>
    </div>
</div>

<!-- Модальное окно для выбора точек разреза -->
<div id="sectionModal" style="display: none; position: fixed; z-index: 10001; left: 20px; bottom: 20px; width: 320px; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 0 15px rgba(0,0,0,0.4);">
    <div style="text-align: center;">
        <h3 style="margin-top: 0; color: #333;">📐 Построение разреза</h3>
        <p style="margin-bottom: 15px; color: #666;">Выберите две точки на карте</p>
        
        <!-- Упрощенное поле ввода глубины -->
        <div style="margin: 15px 0; text-align: left;">
            <label style="display: block; margin-bottom: 8px; font-weight: bold; color: #333;">
                📏 Глубина построения разреза:
            </label>
            <input type="number" 
                   id="sectionDepthInput" 
                   placeholder="По умолчанию - до дна"
                   style="width: 100%; padding: 10px; border: 1px solid #ddd; border-radius: 6px; font-size: 14px;"
                   min="0" step="10">
            <div style="font-size: 12px; color: #888; margin-top: 5px;">
                Оставьте пустым для построения до дна
            </div>
        </div>
        
        <!-- Информация о выбранных точках -->
        <div style="margin: 20px 0;">
            <div id="sectionPointsInfo" style="background: #f8f9fa; padding: 15px; border-radius: 8px; border: 1px solid #e9ecef;">
                <p style="margin: 5px 0;">📍 Точка 1: не выбрана</p>
                <p style="margin: 5px 0;">📍 Точка 2: не выбрана</p>
            </div>
        </div>
        
        <!-- Кнопки управления -->
        <div style="display: flex; gap: 10px; justify-content: center;">
            <button onclick="window.cancelSectionSelection()" 
                    style="padding: 10px 20px; background: #6c757d; color: white; border: none; border-radius: 6px; cursor: pointer;">
                Отмена
            </button>
            <button onclick="window.confirmSectionSelection()" 
                    style="padding: 10px 20px; background: #28a745; color: white; border: none; border-radius: 6px; cursor: pointer;" 
                    id="confirmSectionBtn">
                Построить разрез
            </button>
        </div>
    </div>
</div>

    %JAVASCRIPT_CODE%
</body>
</html>
"""

end
