use GD2015C1
go

/* Realizar un stored procedure: 
- que reciba un código de producto 
- y una fecha 

+ y devuelva la mayor cantidad de días consecutivos a partir de esa fecha que el producto tuvo al menos la venta de una unidad 
(en el día, el sistema de ventas on line está habilitado 24-7 por lo que se deben evaluar todos los días) */

create procedure procedimiento_parcial (@prod_cod char(8), @fecha datetime, @dias_consecutivos int output)
as
begin
	
	declare @fecha_actual date, @fecha_anterior date, @racha_actual int, @racha_max int 
    set @racha_max      = 0
    set @fecha_anterior = null
    set @racha_actual   = 0

	-- La tabla que recorre el cursor, es la tabla que me trae TODAS LAS FECHAS DISTINTAS en las que se vendio el producto
	declare cur cursor for 
	    select distinct convert(date, f.fact_fecha) as fecha
	    from Item_Factura i 
	    join Factura f on f.fact_numero+f.fact_sucursal+f.fact_tipo=i.item_numero+i.item_sucursal+i.item_tipo 
	    where i.item_producto = @prod_cod and f.fact_fecha >= @fecha
	    order by convert(date, f.fact_fecha)

	open cur
	fetch next from cur into @fecha_actual
	-- Llega al while una "fecha actual"
	while @@FETCH_STATUS = 0
    begin
        -- 1. Seteo la racha actual en 1
        if @fecha_anterior is null
        begin
            set @racha_actual = 1
        end

        -- 2. Si no es la "primer fecha", no es null, entonces le sumo un dia y chequeo si es el siguiente o no...
        else if dateadd(day, 1, @fecha_anterior) = @fecha_actual
        
            -- Por consecuencia, seteo la racha + 1
            begin
                set @racha_actual = @racha_actual + 1
            end
        
        -- Aca se "reinicia" la racha en caso de que no se cumplan ni 1 ni 2
        else
        begin
            set @racha_actual = 1
        end

        -- Evaluo actualizar rachas en caso de ser necesario
        if @racha_actual > @racha_max
            set @racha_max = @racha_actual

        -- Guardo la fecha actual como anterior para la proxima iteracion del cursor
        set @fecha_anterior = @fecha_actual

        fetch next from cur into @fecha_actual
    end
	close cur
	deallocate cur

	set @dias_consecutivos = isnull(@racha_max, 0)
end
go