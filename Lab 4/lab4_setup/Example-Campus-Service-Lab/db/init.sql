-- Example Campus Service database initialization.
SET NAMES utf8mb4;
CREATE TABLE users (
    id INT UNSIGNED PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    password_md5 CHAR(32) NOT NULL,
    role VARCHAR(20) NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO users VALUES
(1,'admin','21232f297a57a5a743894a0e4a801fc3','admin',1),
(2,'alice','6384e2b2184bcbf58eccf10ca7a6563c','staff',1),
(3,'bob','9f9d51bc70ef21ca5c14f307980a29d8','staff',1),
(4,'maria','263bce650e68ab4e23f28263760b9fa5','facilities',1);

CREATE TABLE tickets (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    owner_id INT UNSIGNED NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    status VARCHAR(24) NOT NULL,
    priority VARCHAR(12) NOT NULL,
    visibility ENUM('public','private') NOT NULL DEFAULT 'private',
    FOREIGN KEY (owner_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO tickets VALUES
(101,2,'Access card reader intermittently fails','The Building 2 card reader occasionally rejects valid campus access cards. Please investigate the reader firmware and power connection.','In progress','medium','public'),
(102,3,'Meeting room display not detecting laptop','Training Room B display reports no HDMI input. Team members can provide testing availability during the afternoon.','Open','low','public'),
(103,4,'Water dispenser maintenance request','Campus Centre water dispenser needs a filter replacement. Please schedule the service contractor.','Scheduled','low','public'),
(104,2,'Account onboarding for visiting researchers','Two new visiting researchers require guest Wi-Fi registration and temporary access card coordination.','Open','medium','private'),
(105,3,'CONFIDENTIAL: vendor pricing review','Procurement review for departmental vendors. Quotes: Alpha $12,500; Beta $11,900; Gamma $13,200. Internal purchasing review.','In review','high','private'),
(106,1,'CONFIDENTIAL: internal audit notes','Staff access review: retention policy exceptions and escalation owners for the coming quarter.','Open','high','private'),
(107,4,'Loading bay safety barrier inspection','Facilities will inspect the barrier arm and update the maintenance service record.','In progress','medium','public'),
(108,3,'PRIVATE: staff onboarding access roster','Bob owns the onboarding list for teaching assistants. Please reconcile the draft roster with Teaching Support before distribution.','Open','medium','private'),
(109,2,'PRIVATE: Alice research storage request','Alice is arranging encrypted storage access for a research group. Private to Alice.','Open','medium','private');

CREATE TABLE ticket_comments (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    ticket_id INT UNSIGNED NOT NULL,
    author_id INT UNSIGNED NOT NULL,
    body TEXT NOT NULL,
    shared_url VARCHAR(500) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY(ticket_id) REFERENCES tickets(id),
    FOREIGN KEY(author_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO ticket_comments (ticket_id,author_id,body) VALUES
(101,2,'The card reader failed twice this morning. I can provide a video of the issue.'),
(101,4,'Facilities has scheduled a reader inspection for tomorrow.'),
(102,3,'I checked two different cables; the display issue remains.'),
(102,1,'Please update this ticket after the AV team completes the troubleshooting.'),
(103,4,'The replacement filter has been ordered.');

CREATE TABLE articles (
    id INT UNSIGNED PRIMARY KEY,
    title VARCHAR(180) NOT NULL,
    category VARCHAR(60) NOT NULL,
    summary TEXT NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO articles VALUES
(201,'Connect to staff Wi-Fi','IT support','Steps for joining the staff wireless network.'),
(202,'Request a meeting room','Facilities','Reserve training and conference spaces through the campus service desk.'),
(203,'Report a damaged access card','Campus access','Notify the service desk and arrange a replacement access card.'),
(204,'Enable account security alerts','Account security','Configure notification preferences in your staff profile settings.'),
(205,'Submit an AV support request','Classroom technology','Collect device model, cable details and room number before opening a ticket.'),
(206,'Contact the facilities team','Facilities','Submit facilities issues as a service request in the ticket directory.'),
(207,'Review password and access procedures','Account security','Review the campus account registration and security notification procedure.');

CREATE TABLE user_preferences (
    user_id INT UNSIGNED PRIMARY KEY,
    email VARCHAR(120) NOT NULL,
    department VARCHAR(80) NOT NULL,
    security_alerts TINYINT(1) NOT NULL DEFAULT 1,
    alert_email VARCHAR(120) NOT NULL,
    FOREIGN KEY(user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO user_preferences VALUES
(1,'admin@campus.example','IT governance',1,'admin@campus.example'),
(2,'alice@campus.example','Research operations',1,'alice@campus.example'),
(3,'bob@campus.example','Teaching support',1,'bob@campus.example'),
(4,'maria@campus.example','Campus facilities',1,'maria@campus.example');



-- Staff directory.
CREATE TABLE staff_profiles (
    user_id INT UNSIGNED PRIMARY KEY,
    display_name VARCHAR(90) NOT NULL,
    job_title VARCHAR(110) NOT NULL,
    about_me TEXT NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO staff_profiles VALUES
(1,'IT Service Administrator','Service operations lead','Oversees internal system configuration, reporting and account support.'),
(2,'Alice Tan','Research operations officer','I support visiting researchers, access requests and campus facilities coordination.'),
(3,'Bob Lim','Teaching support coordinator','Working with teaching staff to prepare lecture rooms, teaching assistants and equipment.'),
(4,'Maria Chen','Facilities coordinator','I help arrange maintenance, room readiness and facilities service visits.');

CREATE TABLE staff_contacts (
    user_id INT UNSIGNED NOT NULL,
    colleague_id INT UNSIGNED NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, colleague_id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (colleague_id) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO staff_contacts (user_id,colleague_id) VALUES
(2,4),(3,4),(4,2);

-- Saved knowledge articles.
CREATE TABLE article_bookmarks (
    user_id INT UNSIGNED NOT NULL,
    article_id INT UNSIGNED NOT NULL,
    saved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, article_id),
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (article_id) REFERENCES articles(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


-- Access approvals. Administrative approval is a normal business workflow.
CREATE TABLE access_requests (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    requester_id INT UNSIGNED NOT NULL,
    resource_name VARCHAR(160) NOT NULL,
    justification TEXT NOT NULL,
    status ENUM('Pending','Approved','Rejected') NOT NULL DEFAULT 'Pending',
    decided_by INT UNSIGNED NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    decided_at TIMESTAMP NULL DEFAULT NULL,
    FOREIGN KEY (requester_id) REFERENCES users(id),
    FOREIGN KEY (decided_by) REFERENCES users(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
INSERT INTO access_requests (id,requester_id,resource_name,justification,status) VALUES
(301,2,'After-hours Research Lab 2 access',
 'Access required for the visiting research team to carry out evening instrument calibration.','Pending'),
(302,3,'Teaching equipment storeroom access',
 'Access required to issue replacement AV equipment before classes.','Pending'),
(303,4,'Building 3 maintenance corridor access',
 'Facilities inspection access for the upcoming compliance assessment.','Pending');
