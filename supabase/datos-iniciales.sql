-- Datos que ya estaban cargados en la app anterior.
insert into public.docs (path, data) values
  ('privado/costos', '{"valorHora": {}}'::jsonb),
  ('config/main', '{"archivadas": [{"id": "sur", "name": "Barrio Sur", "puestos": [{"area": "Cocina", "id": "jefe", "name": "Jefe de cocina"}, {"area": "Cocina", "id": "segundo", "name": "Segundo de cocina"}, {"area": "Cocina", "id": "cocineros", "name": "Cocineros"}, {"area": "Cocina", "id": "bacha", "name": "Cocinero y bacha"}, {"area": "PedidosYa", "id": "enc-pya", "name": "Encargado de PedidosYa"}]}], "cierres": {}, "entradas": {"a": "11:30", "c": "19:30"}, "locations": [{"id": "norte", "name": "Barrio Norte", "puestos": [{"area": "Cocina", "id": "jefe", "name": "Jefe de cocina"}, {"area": "Cocina", "id": "segundo", "name": "Segundo de cocina"}, {"area": "Cocina", "id": "cocineros", "name": "Cocineros"}, {"area": "Cocina", "id": "bacha", "name": "Cocinero y bacha"}, {"area": "Salón", "id": "enc-salon", "name": "Encargado de salón"}, {"area": "Salón", "id": "mozo1", "name": "Mozo 1"}, {"area": "Salón", "id": "mozo2", "name": "Mozo 2"}, {"area": "Salón", "id": "mozo3", "name": "Mozo 3"}]}, {"id": "prod", "name": "Producción", "puestos": [{"area": "Producción", "id": "enc-prod", "name": "Encargada de producción"}, {"area": "Producción", "id": "coc1", "name": "Cocinero 1"}, {"area": "Producción", "id": "coc2", "name": "Cocinero 2"}, {"area": "Producción", "id": "coc3", "name": "Cocinero 3"}]}], "reglas": {"descanso": 10, "maxSemana": 48}}'::jsonb),
  ('staff/claudia', '{"active": true, "loc": "norte", "name": "Claudia", "puestos": ["norte:jefe"]}'::jsonb),
  ('staff/f8b7tyrs', '{"active": true, "loc": "norte", "name": "Agostina", "puestos": ["norte:enc-salon"]}'::jsonb),
  ('staff/jonathan', '{"active": true, "loc": "norte", "name": "Jonathan", "puestos": ["norte:segundo"]}'::jsonb),
  ('staff/rosario', '{"active": true, "loc": "norte", "name": "Rosario", "puestos": []}'::jsonb),
  ('staff/santiago', '{"active": true, "loc": "norte", "name": "Santiago", "puestos": []}'::jsonb),
  ('staff/sofia', '{"active": true, "loc": "norte", "name": "Sofia", "puestos": []}'::jsonb),
  ('staff/tomas', '{"active": true, "loc": "norte", "name": "Tomas", "puestos": []}'::jsonb),
  ('staff/vicky', '{"active": true, "loc": "norte", "name": "Vicky", "puestos": []}'::jsonb),
  ('staff/yamila', '{"active": true, "loc": "norte", "name": "Yamila", "puestos": []}'::jsonb),
  ('weeks/2026-10-26', '{"assign": [{"d": 0, "id": "ohdc2b5i", "in": "11:30", "loc": "norte", "note": "", "out": "", "p": "jefe", "s": "jonathan", "t": "a"}, {"d": 0, "id": "cuv8ktyk", "in": "19:30", "loc": "norte", "note": "", "out": "", "p": "jefe", "s": "jonathan", "t": "c"}], "updatedAt": "2026-10-30T14:39:43.374Z"}'::jsonb)
on conflict (path) do update set data = excluded.data, updated_at = now();
