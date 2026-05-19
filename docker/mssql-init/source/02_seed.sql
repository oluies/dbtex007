USE ddd_source;
GO

INSERT INTO ddd.locations (unlocode, name) VALUES
    ('USNYC', 'New York'),
    ('DEHAM', 'Hamburg'),
    ('JPYOK', 'Yokohama'),
    ('SESTO', 'Stockholm'),
    ('FIHEL', 'Helsinki'),
    ('CNSHA', 'Shanghai'),
    ('AUMEL', 'Melbourne'),
    ('NLRTM', 'Rotterdam'),
    ('USCHI', 'Chicago'),
    ('CNHKG', 'Hong Kong');
GO

INSERT INTO ddd.voyages (voyage_number, schedule_json) VALUES
    ('V100', N'{"carrier":"Maersk","class":"feeder"}'),
    ('V200', N'{"carrier":"MSC","class":"deep-sea"}'),
    ('V300', N'{"carrier":"ONE","class":"deep-sea"}');
GO

INSERT INTO ddd.cargo (tracking_id, origin_unlocode, destination_unlocode, arrival_deadline) VALUES
    ('ABC123', 'USNYC', 'DEHAM', '2026-06-30T00:00:00'),
    ('JKL567', 'SESTO', 'AUMEL', '2026-07-15T00:00:00'),
    ('XYZ789', 'CNSHA', 'NLRTM', '2026-08-10T00:00:00'),
    ('MNO321', 'FIHEL', 'JPYOK', '2026-09-05T00:00:00'),
    ('PQR654', 'USCHI', 'CNHKG', '2026-10-20T00:00:00');
GO

INSERT INTO ddd.itinerary (cargo_tracking_id) VALUES
    ('ABC123'), ('JKL567'), ('XYZ789'), ('MNO321'), ('PQR654');
GO

INSERT INTO ddd.legs
    (itinerary_cargo_tracking_id, leg_number, voyage_number, load_location, unload_location, load_time, unload_time) VALUES
    ('ABC123', 1, 'V100', 'USNYC', 'NLRTM', '2026-05-01T08:00:00', '2026-05-12T18:00:00'),
    ('ABC123', 2, 'V200', 'NLRTM', 'DEHAM', '2026-05-13T06:00:00', '2026-05-14T20:00:00'),
    ('JKL567', 1, 'V100', 'SESTO', 'DEHAM', '2026-05-20T07:00:00', '2026-05-22T19:00:00'),
    ('JKL567', 2, 'V300', 'DEHAM', 'AUMEL', '2026-05-23T05:00:00', '2026-06-25T17:00:00'),
    ('XYZ789', 1, 'V200', 'CNSHA', 'CNHKG', '2026-06-01T09:00:00', '2026-06-02T15:00:00'),
    ('XYZ789', 2, 'V300', 'CNHKG', 'NLRTM', '2026-06-03T22:00:00', '2026-07-20T11:00:00'),
    ('MNO321', 1, 'V100', 'FIHEL', 'DEHAM', '2026-06-10T08:00:00', '2026-06-12T18:00:00'),
    ('MNO321', 2, 'V300', 'DEHAM', 'JPYOK', '2026-06-14T04:00:00', '2026-07-28T12:00:00'),
    ('PQR654', 1, 'V200', 'USCHI', 'USNYC', '2026-07-01T08:00:00', '2026-07-03T20:00:00'),
    ('PQR654', 2, 'V300', 'USNYC', 'CNHKG', '2026-07-04T22:00:00', '2026-09-15T10:00:00');
GO

INSERT INTO ddd.handling_events
    (event_type, cargo_tracking_id, voyage_number, location_unlocode, completion_time, registration_time) VALUES
    ('RECEIVE', 'ABC123', NULL,   'USNYC', '2026-04-30T15:00:00', '2026-04-30T15:05:00'),
    ('LOAD',    'ABC123', 'V100', 'USNYC', '2026-05-01T08:00:00', '2026-05-01T08:02:00'),
    ('UNLOAD',  'ABC123', 'V100', 'NLRTM', '2026-05-12T18:00:00', '2026-05-12T18:03:00'),
    ('LOAD',    'ABC123', 'V200', 'NLRTM', '2026-05-13T06:00:00', '2026-05-13T06:01:00'),
    ('RECEIVE', 'JKL567', NULL,   'SESTO', '2026-05-19T12:00:00', '2026-05-19T12:04:00'),
    ('LOAD',    'JKL567', 'V100', 'SESTO', '2026-05-20T07:00:00', '2026-05-20T07:02:00'),
    ('UNLOAD',  'JKL567', 'V100', 'DEHAM', '2026-05-22T19:00:00', '2026-05-22T19:04:00'),
    ('RECEIVE', 'XYZ789', NULL,   'CNSHA', '2026-05-31T22:00:00', '2026-05-31T22:06:00'),
    ('LOAD',    'XYZ789', 'V200', 'CNSHA', '2026-06-01T09:00:00', '2026-06-01T09:02:00'),
    ('CUSTOMS', 'XYZ789', NULL,   'CNHKG', '2026-06-02T20:00:00', '2026-06-02T20:11:00'),
    ('RECEIVE', 'MNO321', NULL,   'FIHEL', '2026-06-09T20:00:00', '2026-06-09T20:08:00'),
    ('LOAD',    'MNO321', 'V100', 'FIHEL', '2026-06-10T08:00:00', '2026-06-10T08:01:00'),
    ('RECEIVE', 'PQR654', NULL,   'USCHI', '2026-06-30T18:00:00', '2026-06-30T18:09:00'),
    ('LOAD',    'PQR654', 'V200', 'USCHI', '2026-07-01T08:00:00', '2026-07-01T08:02:00'),
    ('UNLOAD',  'PQR654', 'V200', 'USNYC', '2026-07-03T20:00:00', '2026-07-03T20:05:00');
GO
