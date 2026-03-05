use GD2015C1
go

/* Suponiendo que se aplican los siguientes cambios en el modelo de
datos:

Cambio 1) create table provincia (id 'int primary key, nómbre char(100)) ;
Cambio 2) alter table cliente add pcia_id int null:

Crear el/los objetos necesarios para implementar el concepto de foreign
key entre 2 cliente y provincia,

Nota: No se permite agregar una constraint de tipo FOREIGN KEY entre la
tabla y el campo agregado. */

create trigger git6 on Cliente after insert, update
as
begin
	
	IF EXISTS (
		SELECT 1
		FROM Inserted i
		WHERE (i.pcia_id IS NOT NULL) AND NOT EXISTS (
			SELECT 1
			FROM Provincia p
			WHERE p.id = i.pcia_id
		)
	)
	BEGIN
		PRINT 'Error de Integridad: La provincia asignada no existe.'
		ROLLBACK TRAN
	END

end
go

create trigger git66 on Provincia after delete, update
as
begin
	
	-- Solo rechazo el update si modifica el ID, si no no.
	IF EXISTS(
		SELECT 1
		FROM deleted d 
        JOIN Cliente c ON c.pcia_id = d.id
		WHERE NOT EXISTS (SELECT 1 FROM inserted i WHERE i.id = d.id)
	)
	BEGIN
		PRINT 'Error de Integridad: La provincia está siendo utilizada por al menos 1 cliente. No se puede modificar su ID ni eliminar.'
		ROLLBACK TRAN
	END

end
go
