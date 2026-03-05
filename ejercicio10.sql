USE GD2015C1
GO

/* Implementar una regla de negocio de validación en línea que permita
implementar una lógica de control de precios en las ventas. 

Se deberá poder seleccionar una lista de rubros y aquellos productos de los rubros
que sean los seleccionados no podrán aumentar por mes más de un 2%. 
En caso que no se tenga referencia del mes anterior no validar dicha regla.*/

create table rubros_selec(rubro_id char(8)) go

create trigger validar_ventas on Item_Factura
after insert
as
begin
	
	if exists (

		select 1
		from inserted i 
		join Factura f on f.fact_sucursal = i.item_sucursal and i.item_tipo = f.fact_tipo and i.item_numero = f.fact_numero
		join Producto p on p.prod_codigo=i.item_producto
		join rubros_selec r on r.rubro_id = p.prod_rubro
		
		-- El precio del insertado, debe ser un 2% mayor al "mas caro" vendido en el mes anterior...
		where i.item_precio > 1.02 * (
            
			-- Traeme el mayor precio del item anterior
			select top 1 i_ant.item_precio
            from item_factura i_ant
            join factura f_ant on f_ant.fact_sucursal = i_ant.item_sucursal and f_ant.fact_tipo = i_ant.item_tipo and f_ant.fact_numero   = i_ant.item_numero
           
		   -- Solo me interesan los items cuyo producto sea el mismo al insertado
		   where i_ant.item_producto = i.item_producto
		   
		   -- Y esta venta sea de un mes anterior a la factura "f" (la del insertado...) 
              and year(f_ant.fact_fecha)  = year(dateadd(month,-1,f.fact_fecha))
              and month(f_ant.fact_fecha) = month(dateadd(month,-1,f.fact_fecha))
            order by f_ant.fact_fecha desc
        )
	)

	begin
		rollback transaction
	end
end