# src/routes/css_styles.jl
module CSSStyles

const MAIN_STYLES = """
body { 
    font-family: Arial; 
    margin: 40px; 
}
.container { 
    max-width: 1400px; 
    margin: 0 auto; 
}
.main-content { 
    display: flex; 
    gap: 30px; 
    align-items: flex-start; 
}
.map-container { 
    flex: 1; 
    min-width: 600px; 
}
.controls-container { 
    flex: 0 0 350px; 
    background: #f8f9fa; 
    padding: 25px; 
    border-radius: 12px; 
}
.form-group { 
    margin-bottom: 20px; 
}
label { 
    display: block; 
    margin-bottom: 6px; 
    font-weight: bold; 
}
select, input { 
    padding: 10px; 
    width: 100%; 
    border: 1px solid #ddd; 
    border-radius: 6px; 
}
button { 
    padding: 12px 20px; 
    border: none; 
    border-radius: 6px; 
    cursor: pointer; 
    margin-right: 10px; 
}
#loadMapBtn { 
    background: #007bff; 
    color: white; 
}
#loadAnimationBtn { 
    background: #28a745; 
    color: white; 
}
.map-preview { 
    width: 100%; 
    cursor: pointer; 
    border: 3px solid #e9ecef; 
    border-radius: 12px; 
}
"""

const MODAL_STYLES = """
.modal {
    display: none;
    position: fixed;
    z-index: 1000;
    left: 0;
    top: 0;
    width: 100%;
    height: 100%;
    background-color: rgba(0,0,0,0.95);
}
.portrait-image {
    width: 100%;
    height: auto;
    max-height: 100%;
    object-fit: contain;
}
"""

const SECTION_MODAL_STYLES = """
#sectionModal {
    display: none;
    position: fixed;
    z-index: 10001;
    left: 20px;
    top: 20px;
    width: 300px;
    background: white;
    padding: 20px;
    border-radius: 8px;
    box-shadow: 0 0 10px rgba(0,0,0,0.3);
}
"""

const GRAPH_MODAL_STYLES = """
#graphModal {
    display: none;
    position: fixed;
    z-index: 10000;
    left: 50%;
    top: 50%;
    transform: translate(-50%, -50%);
    width: 400px;
    height: 800px;
    max-width: 90vw;
    max-height: 90vh;
    background: white;
    border-radius: 12px;
    box-shadow: 0 10px 50px rgba(0,0,0,0.5);
    overflow: auto;
}
"""

const CANVAS_STYLES = """
#sectionCanvas {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    pointer-events: none;
    z-index: 1000;    
    display: none;
}

.test-canvas-btn {
    margin: 10px;
    padding: 10px;
    background: purple;
    color: white;
    border: none;
    border-radius: 6px;
    cursor: pointer;
}
"""

const CHECKBOX_STYLES = """
/* Стили для переключателей статистики */
.climatology-controls {
    margin: 15px 0;
    padding: 15px;
    background: rgba(0,0,0,0.03);
    border-radius: 8px;
    border: 1px solid rgba(0,0,0,0.1);
}

.climatology-title {
    display: block;
    margin-bottom: 10px;
    font-weight: bold;
    font-size: 14px;
    color: #333;
}

.climatology-options {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
}

.climatology-option {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    cursor: pointer;
}

.climatology-option input[type="checkbox"] {
    width: 16px;
    height: 16px;
    cursor: pointer;
}

.climatology-option label {
    cursor: pointer;
    user-select: none;
}
"""

# ВАЖНО: Объявляем ALL_STYLES ДО экспорта
const ALL_STYLES = MAIN_STYLES * MODAL_STYLES * SECTION_MODAL_STYLES * GRAPH_MODAL_STYLES * CANVAS_STYLES * CHECKBOX_STYLES

# Экспортируем все константы
export MAIN_STYLES, MODAL_STYLES, SECTION_MODAL_STYLES, GRAPH_MODAL_STYLES, CANVAS_STYLES, ALL_STYLES

end
