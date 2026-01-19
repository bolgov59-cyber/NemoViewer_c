
using Genie.Router, Genie.Renderer.Json, JSON
using GenieSession
using Plots
using Base64: base64encode
using Main: LATEST_DATE, APP_CONFIG
using ..DatabaseFunctions: find_nearest_point, extract_forecast_data, get_climatology_profiles
using LibPQ
import Genie.Requests: rawpayload
using Dates
# Получаем абсолютный путь к директории проекта
#project_root = dirname(@__DIR__)  # Поднимаемся на уровень выше из src/routes
#static_dir = joinpath(project_root, "public", "static")
#color_schemes_path = joinpath(static_dir, "color_schemes.jl")
include("/home/igor/web/NemoViewer/public/static/color_schemes.jl")

# Устанавливаем GR бэкенд
gr()

# Функция для конвертации графика в base64 PNG
function plot_to_png_base64(p)
    try
        temp_file = tempname() * ".png"
        p_with_dpi = plot!(p, dpi=150)
        savefig(p_with_dpi, temp_file)
        png_content = read(temp_file, String)
        rm(temp_file)
        return base64encode(png_content)
    catch e
        println("❌ Ошибка при сохранении PNG: ", e)
        try
            temp_file = tempname() * ".png"
            savefig(p, temp_file)
            png_content = read(temp_file, String)
            rm(temp_file)
            return base64encode(png_content)
        catch
            rethrow(e)
        end
    end
end

# ================== СУЩЕСТВУЮЩИЕ API ENDPOINTS ==================

# Основной API endpoint для данных точки
route("/api/point_data", method = POST) do
    try
        println("🔍 APP_CONFIG: ", APP_CONFIG)
        println("🔍 max_distance: ", APP_CONFIG.max_distance)
        println("🔍 LATEST_DATE: ", LATEST_DATE)
        # 1. Получаем сессию пользователя
        user_session = GenieSession.session(params())
        
        data = JSON.parse(rawpayload())
        lon = parse(Float64, data["longitude"])
        lat = parse(Float64, data["latitude"])
        forecast_hour = get(data, "forecast_hour", 0)
        
        point_data = find_nearest_point(lon, lat, APP_CONFIG.max_distance, LATEST_DATE)
        
        if point_data !== nothing
            processed_data = extract_forecast_data(point_data.data, forecast_hour)
            
            # 2. Сохраняем данные в сессию ЭТОГО пользователя
            GenieSession.set!(user_session, :last_point_data, Dict(
                "longitude" => point_data.lon,
                "latitude" => point_data.lat,
                "all_depths_data" => processed_data,
                "forecast_hour" => forecast_hour
            ))
            
            response = Dict(
                "temperature" => processed_data[1]["tw"],
                "salinity" => processed_data[1]["s"],
                "u_current" => processed_data[1]["u"],
                "v_current" => processed_data[1]["v"],
                "depth" => processed_data[1]["depth"],
                "forecast_hour" => forecast_hour,
                "longitude" => point_data.lon,
                "latitude" => point_data.lat,
                "distance" => point_data.distance,
                "all_depths_data" => processed_data
            )
            
            return Json.json(response)
        else
            return Json.json(Dict("error" => "Данные не найдены"))
        end
    catch e
        return Json.json(Dict("error" => "Ошибка: $(e)"))
    end
end

# API для получения климатических профилей
route("/api/climatology_profiles", method = POST) do
    try
        data = JSON.parse(rawpayload())
        lon = parse(Float64, data["longitude"])
        lat = parse(Float64, data["latitude"])
        
        # Получаем все климатические профили
        temp_climatology = get_climatology_profiles(lon, lat, APP_CONFIG.max_distance)
        salt_climatology = get_climatology_salinity_profiles(lon, lat, APP_CONFIG.max_distance)
        velocity_climatology = get_climatology_velocity_profiles(lon, lat, APP_CONFIG.max_distance)
        
        response = Dict(
            "temperature" => temp_climatology,
            "salinity" => salt_climatology, 
            "velocity" => velocity_climatology
        )
        
        return Json.json(response)
        
    catch e
        return Json.json(Dict("error" => "Ошибка: $(e)"))
    end
end


# API для графика по глубине
route("/api/plot_depth", method = POST) do
    try
        data = JSON.parse(rawpayload())
        parameter = data["parameter"]
        
        # Получаем сессию пользователя
        user_session = GenieSession.session(params())
        
        # Получаем данные из сессии этого пользователя
        point_data = GenieSession.get(user_session, :last_point_data, nothing)
        
        if point_data === nothing
            return "<div style='color: red; padding: 20px;'>Нет данных для построения графика. Сначала получите данные точки.</div>"
        end
        
        all_depths_data = point_data["all_depths_data"]
        longitude = point_data["longitude"]
        latitude = point_data["latitude"]
        
        # Подготавливаем данные для графика
        depths = Float64[h["depth"] for h in all_depths_data]
        
        if parameter == "temperature"
            values = Float64[h["tw"] for h in all_depths_data]
            title = "Температура по глубине"
            xlabel = "Температура (°C)"
            color = :red
        elseif parameter == "salinity"
            values = Float64[h["s"] for h in all_depths_data]
            title = "Соленость по глубине"
            xlabel = "Соленость (‰)"
            color = :blue
        else
            u_values = Float64[h["u"] for h in all_depths_data]
            v_values = Float64[h["v"] for h in all_depths_data]
            values = sqrt.(u_values .^ 2 + v_values .^ 2)
            title = "Скорость течений по глубине"
            xlabel = "Скорость течения (м/с)"
            color = :green
        end
        
        # Создаем график с Plots.jl
        p = plot(values, depths,
           title = title * " (" * string(longitude) * "°, " * string(latitude) * "°)",
           xlabel = xlabel,
           ylabel = "Глубина (м)",
           legend = false,
           linewidth = 3,
           color = color,
           yflip = true,
           size = (370, 950),
           dpi = 150
       )
       
       # === НОВЫЙ КОД ДЛЯ КЛИМАТИЧЕСКИХ ДАННЫХ ===
        include_climatology = get(data, "include_climatology", false)
        climatology_types = get(data, "climatology_types", [])  # ["minmax", "3sigma", "mean"]
        
        if include_climatology && !isempty(climatology_types)
            # Определяем имя таблицы для климатических данных
            table_name = if parameter == "temperature"
                "potemp"
            elseif parameter == "salinity"
                "salt"  
            else  # velocity
                "eken"  # заменить на реальное имя таблицы
            end
            
              # Получаем текущий месяц из даты
            current_date = LATEST_DATE
            current_month = Int(Dates.month(current_date))
            
               # ПРЕОБРАЗУЕМ координаты в Float64
#            point_data = GenieSession.get(user_session, :last_point_data, nothing)
            lon_float = Float64(point_data["longitude"])
            lat_float = Float64(point_data["latitude"])
            
            climatology_response = get_climatology_profiles(lon_float, lat_float, APP_CONFIG.max_distance, table_name, current_month)
    
if climatology_response !== nothing
    clim_mean = climatology_response["mean_values"]
    clim_min = climatology_response["min_values"]
    clim_max = climatology_response["max_values"]
    clim_std = climatology_response["std_values"]
    
    clim_length = length(clim_mean)
    oper_length = length(depths)
    
    println("🔍 Сравнение горизонтов:")
    println("  - Оперативные: $oper_length")
    println("  - Климатические: $clim_length")
    
    if clim_length == oper_length
        # Если горизонты совпадают - рисуем напрямую
        if "mean" in climatology_types
            plot!(p, clim_mean, depths, 
                  linewidth=2, color=:black, linestyle=:dash, label="Среднее")
        end
        if "minmax" in climatology_types  
            plot!(p, clim_min, depths,
                  linewidth=1, color=:gray, linestyle=:dot, label="Min")
            plot!(p, clim_max, depths,
                  linewidth=1, color=:gray, linestyle=:dot, label="Max")
        end
        if "3sigma" in climatology_types
            plot!(p, clim_mean .+ 3*clim_std, depths,
                  linewidth=1, color=:black, linestyle=:dot, label="+3σ")
            plot!(p, clim_mean .- 3*clim_std, depths, 
                  linewidth=1, color=:black, linestyle=:dot, label="-3σ")
        end
    else
        println("⚠️ ВНИМАНИЕ: Разное количество горизонтов! Оперативные: $oper_length, Климатические: $clim_length")
        # Можно добавить интерполяцию или ограничить минимальной длиной
        min_length = min(oper_length, clim_length)
        
        if "mean" in climatology_types
            plot!(p, clim_mean[1:min_length], depths[1:min_length], 
                  linewidth=1, color=:black, linestyle=:dash, label="Среднее")
        end
        if "minmax" in climatology_types
            plot!(p, clim_min[1:min_length], depths[1:min_length], 
                  linewidth=1, color=:black, linestyle=:dash, label="Min")
            plot!(p, clim_max[1:min_length], depths[1:min_length], 
                  linewidth=1, color=:black, linestyle=:dash, label="Max")
        end
        if "3sigma" in climatology_types
            plot!(p, clim_mean[1:min_length] .+ 3*clim_std[1:min_length], depths[1:min_length],
                  linewidth=1, color=:black, linestyle=:dot, label="+3σ")
            plot!(p, clim_mean[1:min_length] .- 3*clim_std[1:min_length], depths[1:min_length], 
                  linewidth=1, color=:black, linestyle=:dot, label="-3σ")
        end
    end
end
        end
        # === КОНЕЦ НОВОГО КОДА ===
        
        # Конвертируем в PNG base64
        html_output = """
        <div style='text-align: center;'>
            <img src='data:image/png;base64,$(plot_to_png_base64(p))' 
                 style='max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 8px;'/>
        </div>
        """
        
        return html_output
        
    catch e
        return "<div style='color: red; padding: 20px;'>Ошибка построения графика: $(e)</div>"
    end
end

# API для TS-профиля
route("/api/plot_ts", method = POST) do
    try
       # Получаем сессию пользователя
        user_session = GenieSession.session(params())
        
        point_data = GenieSession.get(user_session, :last_point_data, nothing)
        
        if point_data === nothing 
            return "<div style='color: red; padding: 20px;'>Нет данных для построения TS-профиля. Сначала получите данные точки.</div>"
        end

        all_depths_data = point_data["all_depths_data"]
        longitude = point_data["longitude"]
        latitude = point_data["latitude"]

        # Подготавливаем данные
        temperatures = Float64[h["tw"] for h in all_depths_data]
        salinities = Float64[h["s"] for h in all_depths_data]
        depths = Float64[h["depth"] for h in all_depths_data]

        # Вычисляем диапазоны значений
        temp_min, temp_max = minimum(temperatures) - 0.5, maximum(temperatures) + 0.5
        sal_min, sal_max = minimum(salinities) - 0.25, maximum(salinities) + 0.25

        p = plot(salinities, depths,
            size = (370, 780),
            linewidth = 3,
            color = :blue,
            xlabel = "Соленость (‰)",
            ylabel = "Глубина (м)",
            label=  "Соленость",
            yflip = true,            
            grid = true,
            xlims = (sal_min, sal_max)
           )

        plot!(twiny(), temperatures, depths,
            linewidth = 3,
            color = :red,
            xlabel = "Температура (°C)",
            label = "Температура",
            yflip = true,
            xaxis = :top, 
            legend = :bottomright,
            grid = true,
            xlims = (temp_min, temp_max)
        )
      
        # Конвертируем в PNG base64
        html_output = """
        <div style='text-align: center;'>
            <img src='data:image/png;base64,$(plot_to_png_base64(p))'
                 style='max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 8px;'/>
        </div>
        """

        return html_output

    catch e
        return "<div style='color: red; padding: 20px;'>Ошибка построения TS-профиля: $(e)</div>"
    end
end

# ================== ФУНКЦИИ ДЛЯ ПОСТРОЕНИЯ РАЗРЕЗА ==================

function find_nearest_point_with_connection(conn, lon::Float64, lat::Float64, max_distance::Float64, target_date::Date)
    partition_schema = Dates.format(target_date, "yyyy-mm-dd")
    
    query = """
    SELECT lon, lat, par,
           ABS(lon - \$1) + ABS(lat - \$2) as distance
    FROM "$(partition_schema)"."_nemo_$(partition_schema)" 
    WHERE dat = \$3 
      AND ABS(lon - \$1) < \$4 
      AND ABS(lat - \$2) < \$4
    ORDER BY distance
    LIMIT 1
    """
    
    result = LibPQ.execute(conn, query, [lon, lat, target_date, max_distance])
    
    if !isempty(result)
        row = first(result)
        parsed_data = JSON.parse(row.par)
        return (lon=row.lon, lat=row.lat, data=parsed_data, distance=row.distance)
    else
        return nothing
    end
end

function interpolate_points(point1, point2, step_degrees=0.25)
    lon1, lat1 = point1["lon"], point1["lat"]
    lon2, lat2 = point2["lon"], point2["lat"]
    
    distance_degrees = sqrt((lon2 - lon1)^2 + (lat2 - lat1)^2)
    num_points = max(ceil(Int, distance_degrees / step_degrees), 2)
    
    lons = range(lon1, lon2, length=num_points)
    lats = range(lat1, lat2, length=num_points)
    
    return collect(zip(lons, lats))
end

function get_parameter_values(processed_data, parameter)
    if parameter == "Tz"
        return Float64[h["tw"] for h in processed_data]
    elseif parameter == "Sz" 
        return Float64[h["s"] for h in processed_data]
    elseif parameter == "UVz"
        u_values = Float64[h["u"] for h in processed_data]
        v_values = Float64[h["v"] for h in processed_data]
        return sqrt.(u_values .^ 2 + v_values .^ 2)
    else
        error("Неизвестный параметр: $parameter")
    end
end

function get_section_data(interpolated_points, parameter, date, forecast_hour)
    section_profiles = []
    
    conn = DatabaseFunctions.get_connection()
    try
        for (i, (lon, lat)) in enumerate(interpolated_points)
            point_data = find_nearest_point_with_connection(conn, lon, lat, APP_CONFIG.max_distance, Date(date))
            
            if point_data !== nothing
                processed_data = DatabaseFunctions.extract_forecast_data(point_data.data, forecast_hour)
                
                profile = Dict(
                    "index" => i,
                    "lon" => lon,
                    "lat" => lat,
                    "depths" => [h["depth"] for h in processed_data],
                    "values" => get_parameter_values(processed_data, parameter)
                )
                push!(section_profiles, profile)
            else
                println("⚠️  Данные не найдены для точки: ($lon, $lat)")
            end
        end
    finally
        close(conn)
    end
    
    return section_profiles  # ← ВОЗВРАЩАЕМ ТОЛЬКО ПРОФИЛИ
end

function build_section_matrix(section_profiles, max_depth_limit=nothing)
    if isempty(section_profiles)
        error("Нет данных для построения разреза")
    end
    
    # Находим максимальное количество горизонтов среди ВСЕХ профилей
    max_horizons = maximum(length(p["depths"]) for p in section_profiles)
    num_points = length(section_profiles)
    
    println("🔍 Максимальное количество горизонтов: $max_horizons")
    println("🔍 Количество точек: $num_points")
    
    # СОЗДАЕМ МАТРИЦУ С КОНКРЕТНЫМ ТИПОМ ДАННЫХ
    matrix = fill(convert(Float64, NaN), num_points, max_horizons)
    distances_km = zeros(Float64, num_points)
    
    total_distance_km = 0.0
    for i in 1:num_points
        if i > 1
            prev_lon, prev_lat = section_profiles[i-1]["lon"], section_profiles[i-1]["lat"]
            curr_lon, curr_lat = section_profiles[i]["lon"], section_profiles[i]["lat"]
            
            delta_deg = sqrt((curr_lon - prev_lon)^2 + (curr_lat - prev_lat)^2)
            segment_distance_km = delta_deg * 111.0
            total_distance_km += segment_distance_km
        end
        
        distances_km[i] = total_distance_km
        
        # Копируем значения с явным преобразованием типа
        current_horizons = length(section_profiles[i]["depths"])
        if current_horizons > 0
            # Явно преобразуем значения к Float64
            values_float = Float64.(section_profiles[i]["values"])
            matrix[i, 1:current_horizons] = values_float
        end
    end
    
    # НАХОДИМ ПРОФИЛЬ С МАКСИМАЛЬНЫМ КОЛИЧЕСТВОМ ГОРИЗОНТОВ
    max_horizons_count = 0
    deepest_profile_index = 1
    
    for (i, profile) in enumerate(section_profiles)
        horizons_count = length(profile["depths"])
        if horizons_count > max_horizons_count
            max_horizons_count = horizons_count
            deepest_profile_index = i
        end
    end
    
    # Используем глубины из профиля с максимальным количеством горизонтов
    depth_grid = Float64.(section_profiles[deepest_profile_index]["depths"])
    
    # ПРИМЕНЯЕМ ЛИМИТ ГЛУБИНЫ ЕСЛИ ЗАДАН
    if max_depth_limit !== nothing
        # Находим индексы глубин, которые меньше или равны лимиту
        valid_indices = depth_grid .<= max_depth_limit
        if any(valid_indices)
            depth_grid = depth_grid[valid_indices]
            matrix = matrix[:, 1:length(depth_grid)]
            println("🎯 Применен лимит глубины: $max_depth_limit м")
            println("🎯 Новый размер depth_grid: $(length(depth_grid))")
        else
            println("⚠️  Лимит глубины $max_depth_limit м слишком мал, используем все глубины")
        end
    end
    
    println("🎯 Используем глубины из профиля $deepest_profile_index с $(length(depth_grid)) горизонтами")
    println("🎯 Размер depth_grid: $(length(depth_grid)), размер matrix: $(size(matrix))")
    
    return matrix, depth_grid, distances_km
end

# Функция интерполяции на стандартные глубины
function interpolate_to_standard_depths(original_depths, original_values, target_depths)
    # Простая линейная интерполяция
    interp_values = zeros(length(target_depths))
    
    for (i, target_depth) in enumerate(target_depths)
        # Находим ближайшие известные глубины
        idx = findlast(original_depths .<= target_depth)
        next_idx = findfirst(original_depths .>= target_depth)
        
        if idx !== nothing && next_idx !== nothing && idx != next_idx
            # Линейная интерполяция
            depth1, depth2 = original_depths[idx], original_depths[next_idx]
            value1, value2 = original_values[idx], original_values[next_idx]
            interp_values[i] = value1 + (value2 - value1) * (target_depth - depth1) / (depth2 - depth1)
        elseif idx !== nothing
            interp_values[i] = original_values[idx]
        else
            interp_values[i] = NaN
        end
    end
    
    return interp_values
end

function create_section_plot(distance_grid, depth_grid, parameter_matrix, parameter_name, region, depth_level)
    println("🎨 Используем цветовую схему для: $region, $parameter_name, $depth_level")
    
    # Получаем цветовую схему
    color_scheme = get_colormap_for_section(region, parameter_name, depth_level)
    
    # Создаем кастомную цветовую карту из ваших данных
    custom_colors = [RGB(c[1], c[2], c[3]) for c in eachrow(color_scheme.Цвета)]
    
    # Используем диапазоны значений из цветовой схемы
    vmin, vmax = color_scheme.vmin, color_scheme.vmax
    
    # Создаем уровни изо-линий на основе диапазонов
    levels = color_scheme.Диапазоны
    
    # Явно преобразуем все к Float64 для безопасности
    distance_grid_float = Float64.(distance_grid)
    depth_grid_float = Float64.(depth_grid)
    parameter_matrix_float = Float64.(parameter_matrix)
    
    # Создаем график с кастомной цветовой схемой
    p = contourf(distance_grid_float, depth_grid_float, parameter_matrix_float',
                 fill=true,
                 color=custom_colors,
                 levels=levels,
                 clims=(vmin, vmax),
                 xlabel="Расстояние вдоль разреза (км)",
                 ylabel="Глубина (м)",
                 title="Разрез: $parameter_name ($region)",
                 yflip=true,
                 size=(600, 400),
                 dpi=150)
    
    # Добавляем контурные линии
    contour!(p, distance_grid_float, depth_grid_float, parameter_matrix_float',
             color=:black, linewidth=0.5, levels=levels, alpha=0.6)
    
    return p
end


function get_colormap_for_section(region::String, parameter::String, depth::String)
    # Определяем индексы на основе региона и параметра
    region_idx = if region == "wo"
        1
    elseif region == "arctic" 
        2
    else # "antarc"
        3
    end
    
    param_idx = if parameter == "Sz"
        1
    elseif parameter == "Tz"
        2
    else # "UVz" или другие
        3
    end
    
    depth_idx = if depth == "0p5"
        1
    elseif depth == "97"
        2
    else # "1046"
        3
    end
    
    # Возвращаем соответствующую цветовую схему
    return arargpl[param_idx, depth_idx, region_idx]
end

# API для построения разреза
route("/api/section_plot", method=POST) do
    try
        data = JSON.parse(rawpayload())
        
        println("📐 Начало построения разреза...")
        
        # Проверяем обязательные параметры
#        required_keys = ["point1", "point2", "parameter", "region", "depth", "date", "forecast_hour"]
#        for key in required_keys
#            if !haskey(data, key)
#                return Json.json(Dict("error" => "Отсутствует обязательный параметр: $key"))
#            end
#        end
        
       # Получаем сессию пользователя
        user_session = GenieSession.session(params())
        
        # Получаем точку из сессии этого пользователя
        point_data = GenieSession.get(user_session, :last_point_data, nothing)
        
        if point_data === nothing
            return Json.json(Dict("error" => "Сначала получите данные точки, кликнув на карту"))
        end
        
        # ИСПРАВЛЕННАЯ обработка глубины
        max_depth_limit = nothing
        if haskey(data, "max_depth_limit") && data["max_depth_limit"] !== nothing
            max_depth_limit = data["max_depth_limit"]
            println("🎯 Лимит глубины: $max_depth_limit м")
        else
            println("🎯 Глубина: до дна")
        end
        
        # 1. Интерполяция точек
        interpolated_points = interpolate_points(data["point1"], data["point2"])
        println("✅ Интерполировано точек: ", length(interpolated_points))
        
        # 2. Получение данных
        section_profiles = get_section_data(interpolated_points, 
                                          data["parameter"], 
                                          data["date"], 
                                          data["forecast_hour"])
        println("✅ Получено профилей: ", length(section_profiles))
        
        if isempty(section_profiles)
            return Json.json(Dict("error" => "Не удалось получить данные для построения разреза"))
        end
        
        # 3. Построение матрицы С УЧЕТОМ ЛИМИТА ГЛУБИНЫ
        matrix, depths, distances = build_section_matrix(section_profiles, max_depth_limit)
        println("✅ Построена матрица: ", size(matrix))
        
        # 4. Визуализация с цветовыми схемами
        region = data["region"]
        depth_level = data["depth"]
        p = create_section_plot(distances, depths, matrix, data["parameter"], region, depth_level)
        
        # 5. Формирование HTML ответа
        depth_info = max_depth_limit === nothing ? "до дна" : "до $max_depth_limit м"
        html_output = """
        <div style='text-align: center;'>
            <h3>📐 Разрез: $(data["parameter"])</h3>
            <p>От ($(data["point1"]["lon"]), $(data["point1"]["lat"])) до ($(data["point2"]["lon"]), $(data["point2"]["lat"]))</p>
            <p>Длина: $(round(distances[end], digits=2)) км | Глубина: $depth_info</p>
            <img src='data:image/png;base64,$(plot_to_png_base64(p))' 
                 style='max-width: 100%; height: auto; border: 1px solid #ddd; border-radius: 8px;'/>
        </div>
        """
        
        return html_output
        
    catch e
        println("❌ Ошибка в построении разреза: ", e)
        println("Стек вызовов: ", stacktrace(catch_backtrace()))
        return "<div style='color: red; padding: 20px;'>Ошибка построения разреза: $(e)</div>"
    end
end
