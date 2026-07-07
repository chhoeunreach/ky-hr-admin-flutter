CREATE TABLE hrs_addon_social_rewards (
    id INT AUTO_INCREMENT PRIMARY KEY,
    existing_employee_id INT NOT NULL,
    log_date DATE NOT NULL,
    fb_post_url TEXT NOT NULL,
    fb_story_url TEXT NOT NULL,
    tiktok_url TEXT NOT NULL,
    fb_post_photo_url TEXT NULL,
    fb_story_photo_url TEXT NULL,
    tiktok_photo_url TEXT NULL,
    reward_points INT DEFAULT 1,
    is_locked TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY idx_emp_date (existing_employee_id, log_date)
);

CREATE TABLE hrs_addon_reward_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    target_record_id INT NOT NULL,
    admin_id INT NOT NULL,
    action_taken VARCHAR(100) DEFAULT 'MANUAL_OVERRIDE_UPDATE',
    reason TEXT NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
