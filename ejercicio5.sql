USE GD2015C1
GO

/* Actualmente el campo fact_vendedor representa al empleado que vendió
la factura. Implementar el/los objetos necesarios para respetar la
integridad referencial de dicho campo suponiendo que no existe una
foreign key entre ambos.

NOTA: No se puede usar una foreign key para el ejercicio, deberá buscar
otro método */

CREATE TRIGGER GIT7 ON FACTURA AFTER INSERT
AS
BEGIN
	
	if exists (
		select 1
		from Inserted i
		where i.fact_vendedor is not null and not exists (
			select 1
			from Empleado e
			where e.empl_codigo = i.fact_vendedor
		)
	)

	begin
		print 'El vendedor no existe'
		rollback tran
	end

END
GO

CREATE TRIGGER GIT77 ON EMPLEADO AFTER DELETE, UPDATE
AS
BEGIN
	
	if exists (
		select 1
		from deleted d join factura f on f.fact_vendedor = d.empl_codigo
		where not exists (select 1 from inserted i where i.empl_codigo = d.empl_codigo)
	)

	begin
		print 'El empleado tiene al menos una factura/venta ...'
		rollback tran
	end

END
GO

