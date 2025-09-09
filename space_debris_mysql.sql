-- Create database
CREATE DATABASE IF NOT EXISTS sd_simple;
USE sd_simple;

-- Debris table
CREATE TABLE debris (
  debris_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100),
  size_m DECIMAL(6,3) NOT NULL,
  altitude_km DECIMAL(8,3) NOT NULL,
  velocity_kms DECIMAL(6,3)
);

-- Satellites table
CREATE TABLE satellites (
  sat_id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  altitude_km DECIMAL(8,3) NOT NULL,
  velocity_kms DECIMAL(6,3)
);

-- Close approaches
CREATE TABLE close_approaches (
  approach_id INT AUTO_INCREMENT PRIMARY KEY,
  debris_id INT,
  sat_id INT,
  observed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  note VARCHAR(255),
  FOREIGN KEY (debris_id) REFERENCES debris(debris_id),
  FOREIGN KEY (sat_id) REFERENCES satellites(sat_id)
);

-- Risk assessments
CREATE TABLE risk_assessments (
  assessment_id INT AUTO_INCREMENT PRIMARY KEY,
  debris_id INT,
  sat_id INT,
  assessed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  distance_km DECIMAL(10,4),
  rel_vel_kms DECIMAL(6,4),
  raw_score DECIMAL(10,6),
  risk_score DECIMAL(5,2),
  note VARCHAR(255),
  FOREIGN KEY (debris_id) REFERENCES debris(debris_id),
  FOREIGN KEY (sat_id) REFERENCES satellites(sat_id)
);

-- Stored procedure to compute and insert risk
DELIMITER //
CREATE PROCEDURE assess_and_insert(IN p_debris INT, IN p_sat INT, IN p_note VARCHAR(255))
BEGIN
  DECLARE dist DOUBLE;
  DECLARE relv DOUBLE;
  DECLARE raw DOUBLE;
  DECLARE norm DOUBLE;
  DECLARE d_alt DOUBLE;
  DECLARE s_alt DOUBLE;
  DECLARE d_vel DOUBLE;
  DECLARE s_vel DOUBLE;
  DECLARE d_size DOUBLE;

  SELECT altitude_km, velocity_kms, size_m INTO d_alt, d_vel, d_size FROM debris WHERE debris_id = p_debris;
  SELECT altitude_km, velocity_kms INTO s_alt, s_vel FROM satellites WHERE sat_id = p_sat;

  SET dist = ABS(d_alt - s_alt);
  SET relv = ABS(d_vel - s_vel);
  IF relv < 0.0001 THEN SET relv = 0.0001; END IF;

  SET raw = (d_size * (relv + 0.1)) / (dist + 1.0);
  SET norm = raw * 25.0;
  IF norm < 0 THEN SET norm = 0; END IF;
  IF norm > 100 THEN SET norm = 100; END IF;

  INSERT INTO risk_assessments (debris_id, sat_id, distance_km, rel_vel_kms, raw_score, risk_score, note)
  VALUES (p_debris, p_sat, dist, relv, raw, norm, p_note);
END//
DELIMITER ;

-- Trigger: auto assess on insert
DELIMITER //
CREATE TRIGGER trg_auto_assess
AFTER INSERT ON close_approaches
FOR EACH ROW
BEGIN
  CALL assess_and_insert(NEW.debris_id, NEW.sat_id, CONCAT('auto: ', NEW.note));
END//
DELIMITER ;

-- Sample data
INSERT INTO debris (name, size_m, altitude_km, velocity_kms) VALUES
('D-Alpha', 0.50, 550.0, 7.60),
('D-Beta', 1.20, 548.7, 7.62),
('D-Chunk', 0.10, 400.5, 7.67);

INSERT INTO satellites (name, altitude_km, velocity_kms) VALUES
('Comms-1', 549.2, 7.61),
('Imager-1', 400.6, 7.66);

-- Insert close approaches (auto risk generated)
INSERT INTO close_approaches (debris_id, sat_id, note) VALUES (1, 1, 'sensor alert');
INSERT INTO close_approaches (debris_id, sat_id, note) VALUES (2, 1, 'predicted pass');
INSERT INTO close_approaches (debris_id, sat_id, note) VALUES (3, 2, 'radar detection');

-- Check results
SELECT * FROM risk_assessments;
