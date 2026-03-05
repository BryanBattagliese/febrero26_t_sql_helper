use [gd2015c1] 
go

/* FUNCIóN: producto compuesto: no compuesto por si mismo (recursiva) */

create function no_compuesto_recursiva (@producto char(8), @componente char(8))
returns int
as
begin

	-- Declaro el retorno
	declare @ret int = 0, @comp char(8)

	-- Composicion directa
	if (@producto = @componente)
		select @ret = 1

	-- Composicion indirecta: cursor para evaluar los productos q componen al componente
	else
		begin
			declare cursor_comp cursor for select comp_componente from Composicion where comp_producto = @componente
			open cursor_comp
			fetch cursor_comp next into @comp
			while @@FETCH_STATUS = 0 and @ret = 0
				begin
					select @ret = dbo.no_compuesto_recursiva(@producto, @comp)
					fetch cursor_comp next into @comp
				end
			close cursor_comp
			deallocate cursor_comp
		end

	return @ret
end
go

/* FUNCIóN: salario jefe: no mayor al 20% de la suma de sus empleados */

create function salario_emp (@jefe numeric(6))
returns decimal(12,2)
as
begin
	
	declare @ret decimal(12,2) = 0
	(
		select @ret = sum(e.empl_salario)+dbo.salario_emp(empl_codigo)
		from Empleado e
		where e.empl_jefe = @jefe
	)
	return @ret

end
go
create trigger salario_jefe_2 on Empleado for insert, update
as
begin
	
	if (
		select count (*) 
		from inserted i 
		where (
			-- traigo el salario del jefe
			select e.empl_salario
			from Empleado e
			where i.empl_jefe = e.empl_codigo

			-- comparo contra la funcion de suma de salarios
		) > dbo.salario_emp(i.empl_jefe) * 0.2
	) > 0

	begin
		rollback tran
	end

	if (
		select count (*) 
		from deleted d
		where (
			-- traigo el salario del jefe
			select e.empl_salario
			from Empleado e
			where d.empl_jefe = e.empl_codigo

			-- comparo contra la funcion de suma de salarios
		) > dbo.salario_emp(d.empl_jefe) * 0.2
	) > 0

	begin
		rollback tran
	end

end
go

/* Si un cliente compra un producto compuesto a un precio menor que la suma de los componentes
imprimir: fecha, cliente, productos y precio total. Si el precio es menor a la mitad de la suma de los componentes
NO PERMITIR */

create function sum_comp_comp (@prod_comp char(8))
returns decimal (12,2)
as
begin
	
	declare @ret decimal (12,2) = 0

	-- caso 1: si no existe en composicion
	if not exists(select 1 from Composicion where comp_producto = @prod_comp)
	begin
		select @ret = prod_precio from Producto where prod_codigo = @prod_comp
	end

	-- caso 2: si es un compuesto
	else
		begin
			select @ret = sum(dbo.sum_comp_comp(comp_componente) * comp_cantidad)
			from Composicion
			where comp_producto = @prod_comp
		end

	return @ret

end
go

create trigger precio_compra on Item_factura for insert
as
begin
	
	if( select count (*)
		from inserted i
		where i.item_precio < (dbo.sum_comp_comp(i.item_producto) * 0.5) ) > 0
	
	begin
		rollback tran
	end

	else if( select count (*)
		from inserted i
		where i.item_precio < (dbo.sum_comp_comp(i.item_producto))) > 0
	
	begin
		print('x y z')
	end

end
go

/* -- -- -- -- -- -- -- -- --
--	  EJERCICIO 3: T-SQL   --
-- -- -- -- -- -- -- -- -- --

Corregir la tabla empleado en caso de que sea necesario:
- Debe existir un unico gerente general (1 solo empleado sin jefe)
- Si detecta que hay más, debera elegir el de mayor salario
- Si hay mas de uno, se seleccionara el de mayor antiguedad
- Retornar la cantidad de empleados que habia sin jefe, antes de la ejecución */

alter procedure ejercicio_3 @cantidad int output
as
begin
	declare @gg numeric(6)

	-- Guardo en la variable cantidad, todos los empleados sin jefe
	select @cantidad = count(*)
	from Empleado e 
	where e.empl_jefe is null

	-- Elijo al gerente general
	select @gg = (select top 1 empl_codigo
	from Empleado
	where empl_jefe is null
	order by empl_salario desc, empl_ingreso asc)

	-- Actualizo el jefe a los empleados sin jefe
	update Empleado set empl_jefe = @gg where empl_jefe is null and empl_codigo <> @gg
end

-- Como probamos el procedimiento

begin
	declare @cant INT
	exec dbo.ejercicio_3 @cant
	print @cant
end

select * from Empleado
go

/* -- -- -- -- -- -- -- -- --
--	 EJERCICIO 10: T-SQL   --
-- -- -- -- -- -- -- -- -- --

Crear el/los objetos de base de datos que ante el intento de borrar un artículo
verifique que no exista stock y si es así lo borre en caso contrario que emita un
mensaje de error. */

create trigger ejercicio_10_after on producto after delete
as
begin
	
	if(
		select count (*) 
		from deleted d join STOCK on stoc_producto = d.prod_codigo
		where stoc_cantidad > 0
		
	) > 0
	begin
		rollback
		raiserror('nao nao')
	end 
end
go

create trigger ejercicio_10_InstOf on producto instead of delete
as
begin
	
	delete from producto where prod_codigo not in (
		select prod_codigo
		from deleted d join STOCK on stoc_producto = d.prod_codigo
		where stoc_cantidad <= 0 
	)

end
go

/* -- -- -- -- -- -- -- -- --
--	 EJERCICIO 11: T-SQL   --
-- -- -- -- -- -- -- -- -- --

Cree el/los objetos de base de datos necesarios para que dado un código de
empleado se retorne la cantidad de empleados que este tiene a su cargo (directa o
indirectamente). Solo contar aquellos empleados (directos o indirectos) que
tengan un código mayor que su jefe directo. */

create function ejer_11 (@codigo int)
returns int
begin
	
	declare @conteo int, @emp numeric(6)
	
	declare c1 cursor for 
		select empl_codigo
		from Empleado 
		where empl_jefe = @codigo and empl_codigo > empl_jefe
	open c1
	fetch c1 next into @emp

	select @conteo = 0

	while @@FETCH_STATUS = 0
	begin
		select @conteo = @conteo + 1 + dbo.ejer_11(@emp)
		fetch c1 next into @emp
	end

	close c1
	deallocate c1
	return @conteo

end
go

create function ejer_11_2 (@cod numeric(6))
returns int
as
begin 
	
	return (
		select isnull(count(*) + sum(dbo.ejj11(empl_codigo)), 0)
		from Empleado
		where empl_jefe = @cod and @cod < empl_codigo
	)

end
go


/* Ejercicio 24 guia */
/* Se requiere recategorizar los encargados asignados a los depositos. Para ello
cree el o los objetos de bases de datos necesarios que lo resueva, teniendo en
cuenta que un deposito no puede tener como encargado un empleado que
pertenezca a un departamento que no sea de la misma zona que el deposito, si
esto ocurre a dicho deposito debera asignársele el empleado con menos
depositos asignados que pertenezca a un departamento de esa zona. */

create procedure ej24 
as
begin
	declare @depo char(2), @depo_zona char(3)
	declare cur cursor for

		-- Me traigo todos los depos a corregir
		select depo_codigo, depo_zona
		from deposito join Empleado on empl_codigo = depo_encargado join Departamento on empl_departamento = depa_codigo
		where depo_zona <> depa_zona

	open cur
	fetch next from cur into @depo, @depo_zona
	while @@FETCH_STATUS = 0
	
	begin
		update DEPOSITO set depo_encargado = 

		-- Selecciono al nuevo encargado
		( select top 1 empl_codigo	
		from Empleado join Departamento on empl_departamento = depa_codigo
		where @depo_zona = depa_zona
		order by (select count(*) from DEPOSITO where depo_encargado = empl_codigo))
		
		where depo_codigo = @depo
		
		fetch next from cur into @depo, @depo_zona
	end
	
	close cur
	deallocate cur
end
go

/* Ejercicio 23 guia */
/* Desarrolle el/los elementos de base de datos necesarios para que ante una venta
automaticamante se controle que en una misma factura no puedan venderse más
de dos productos con composición. Si esto ocurre debera rechazarse la factura. */

create trigger ej23 on Item_Factura for insert
as
begin

	if(
		
		select count (*)
		from Item_Factura
		where item_producto in (select comp_producto from Composicion)
		group by item_tipo, item_sucursal, item_numero -- Asi me aseguro que sea en una misma factura...
	
	) > 2

	begin
		delete from Item_Factura where item_tipo, item_sucursal, item_numero in select(item_tipo, item_sucursal, item_numero from inserted)
		delete from Factura where fact_tipo, fact_sucursal, fact_numero in select(item_tipo, item_sucursal, item_numero from inserted)
	end

end
go

