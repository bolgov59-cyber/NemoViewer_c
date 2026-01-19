module DatabaseFunctions
using LibPQ, Dates, JSON
include("../config/database.jl")
export find_nearest_point, extract_forecast_data, get_latest_date, get_connection, get_climatology_profiles

# Функция для подключения к БД
function get_connection()
    conn_str = "dbname=$(DB_CONFIG.dbname) user=$(DB_CONFIG.user) password=$(DB_CONFIG.password) host=$(DB_CONFIG.host) port=$(DB_CONFIG.port)"
    println("🔗 Попытка подключения к БД: $conn_str")
    try
        conn = LibPQ.Connection(conn_str)
        println("✅ Подключение к БД успешно")
        return conn
    catch e
        println("❌ Ошибка подключения к БД: ", e)
        rethrow(e)
    end
end

# Функция для получения последней даты
function get_latest_date()
    conn = get_connection()
    try
        result = execute(conn, "SELECT MAX(dat) as latest_date FROM _nemo")
        return first(result).latest_date
    finally
        close(conn)
    end
end

function find_nearest_point(lon::Float64, lat::Float64, max_distance::Float64, target_date::Date)
    # println("🔍 Поиск точки: lon=$lon, lat=$lat, date=$target_date")  # ← ЗАКОММЕНТИРОВАТЬ
    
    conn = get_connection()
    try
        partition_schema = Dates.format(target_date, "yyyy-mm-dd")
        table_name = "_nemo_$(partition_schema)"
        # println("📂 Используем таблицу: $partition_schema.$table_name")  # ← ЗАКОММЕНТИРОВАТЬ
        
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
        
        # println("📋 Выполняем запрос: ", query)  # ← ЗАКОММЕНТИРОВАТЬ
        result = execute(conn, query, [lon, lat, target_date, max_distance])
        
        if !isempty(result)
            row = first(result)
            # println("✅ Найдена точка: lon=$(row.lon), lat=$(row.lat), distance=$(row.distance)")  # ← ЗАКОММЕНТИРОВАТЬ
            
            # ПРЕОБРАЗУЕМ JSONB строку в объект Julia!
            # println("📦 Raw par data type: ", typeof(row.par))  # ← ЗАКОММЕНТИРОВАТЬ
            # println("📦 Raw par data: ", row.par)  # ← ЗАКОММЕНТИРОВАТЬ
            
            parsed_data = JSON.parse(row.par)
            # println("✅ JSON успешно распарсен")  # ← ЗАКОММЕНТИРОВАТЬ
            
            return (lon=row.lon, lat=row.lat, data=parsed_data, distance=row.distance)
        else
            # println("⚠️  Точка не найдена")  # ← ЗАКОММЕНТИРОВАТЬ
            return nothing
        end
    catch e
        # println("❌ Ошибка в find_nearest_point: ", e)  # ← ЗАКОММЕНТИРОВАТЬ
        rethrow(e)
    finally
        close(conn)
        # println("🔌 Соединение с БД закрыто")  # ← ЗАКОММЕНТИРОВАТЬ
    end
end

# Извлечение данных для конкретного времени прогноза
# Исправленная функция для извлечения данных прогноза
function extract_forecast_data(raw_data, forecast_hour::Int)
    # println("⏰ Извлечение данных для forecast_hour=$forecast_hour")  # ← ЗАКОММЕНТИРОВАТЬ

    # Правильное вычисление индекса времени
    if forecast_hour == 0
        time_index = 1  # Анализ (000 часов)
    else
        time_index = forecast_hour ÷ 24 + 1  # Прогноз с шагом 24 часа
    end
    
    # println("📊 Используем временной индекс: $time_index")  # ← ЗАКОММЕНТИРОВАТЬ

    processed_data = []
    
    for horizon_data in raw_data
        processed_horizon = Dict()
        
        for (param_name, param_values) in horizon_data
            # Если параметр - массив (временной ряд), берем значение по индексу time_index
            if param_values isa Vector && param_name != "depth"
                # Проверяем, что индекс существует в массиве
                if 1 <= time_index <= length(param_values)
                    processed_horizon[param_name] = param_values[time_index]
                    # println("✅ $param_name: $(param_values[time_index]) (индекс $time_index)")  # ← ЗАКОММЕНТИРОВАТЬ
                else
                    # Если индекс вне диапазона, берем последнее доступное значение
                    if length(param_values) > 0
                        processed_horizon[param_name] = param_values[end]
                        # println("⚠️  Используем последнее значение для $param_name: $(param_values[end])")  # ← ЗАКОММЕНТИРОВАТЬ
                    else
                        processed_horizon[param_name] = NaN
                        # println("❌ Массив $param_name пуст")  # ← ЗАКОММЕНТИРОВАТЬ
                    end
                end
            else
                # Если параметр не массив (например, глубина), оставляем как есть
                processed_horizon[param_name] = param_values
                # println("📋 $param_name: $param_values (скалярное значение)")  # ← ЗАКОММЕНТИРОВАТЬ
            end
        end
        
        push!(processed_data, processed_horizon)
    end
    
    # println("✅ Данные прогноза обработаны")  # ← ЗАКОММЕНТИРОВАТЬ
    return processed_data
end

# Функция для получения климатических профилей

function get_climatology_profiles(lon, lat, max_distance, param_name::String, mon::Int)
    conn = get_connection()
    try

        query = """
        SELECT ST_X(coor) as lon, ST_Y(coor) as lat,
               clim as mean_values,
               min_clim as min_values, 
               max_clim as max_values,
               std_clim as std_values
        FROM $param_name  
        WHERE month = $mon
          AND ST_DWithin(coor, ST_SetSRID(ST_MakePoint(\$1, \$2), 4326), \$3)
        ORDER BY ST_Distance(coor, ST_SetSRID(ST_MakePoint(\$1, \$2), 4326))
        LIMIT 1
        """
        println("Месяц ", mon)
        println(query)
        result = execute(conn, query, [lon, lat, max_distance])
        
        if !isempty(result)
            row = first(result)
            clim_length = length(row.mean_values)
            println("✅ Климатические данные: $clim_length горизонтов")
            return Dict(
                "lon" => row.lon,
                "lat" => row.lat,
                "mean_values" => row.mean_values,
                "min_values" => row.min_values,
                "max_values" => row.max_values, 
                "std_values" => row.std_values
            )
        else
            return nothing
        end
    finally
        close(conn)
    end
end

end
