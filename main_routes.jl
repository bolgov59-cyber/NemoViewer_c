# src/routes/main_routes.jl
using Genie.Router

# Импортируем наши модули
include("css_styles.jl")
include("html_templates.jl") 
include("javascript_code.jl")

function main_routes()
    route("/") do
        # Получаем актуальную дату
        latest_date = Main.LATEST_DATE
        
        # Собираем полный HTML
        full_html = HTMLTemplates.COMPLETE_HTML_TEMPLATE
        
        # Заменяем плейсхолдеры на реальные значения
        full_html = replace(full_html, "%LATEST_DATE%" => string(latest_date))
        full_html = replace(full_html, "%JAVASCRIPT_CODE%" => """
            <script>
            $(JavaScriptCode.ALL_JAVASCRIPT)
            </script>
        """)
        
        return full_html
    end
#    include("/home/igor/web/NemoViewer/src/routes/api_routes.jl")
end

export main_routes
