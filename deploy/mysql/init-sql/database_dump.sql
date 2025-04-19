


-- blog_db 데이터베이스 구조 내보내기
CREATE DATABASE IF NOT EXISTS `blog_db` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci */;
USE `blog_db`;

-- 테이블 blog_db.posts 구조 내보내기
CREATE TABLE IF NOT EXISTS `posts` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) unsigned NOT NULL,
  `title` varchar(255) NOT NULL,
  `content` text NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  PRIMARY KEY (`id`)
) ENGINE=InnoDB AUTO_INCREMENT=17 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 테이블 데이터 blog_db.posts:~10 rows (대략적) 내보내기
DELETE FROM `posts`;
INSERT INTO `posts` (`id`, `user_id`, `title`, `content`, `created_at`, `updated_at`) VALUES
	(1, 1, 'ㅇㅇㅇ', '<p>ㅇㅇㅇㅇㅇ</p>', '2025-04-18 04:14:43', '2025-04-18 04:14:43'),
	(2, 1, 'dddd', '<p><img src="../uploads/a353cfc3-676c-48ca-a435-048923b13ee5.png" alt="" width="2624" height="1154"></p>', '2025-04-18 04:33:08', '2025-04-18 04:33:08'),
	(3, 1, 'ddd', '<p>dddd</p>', '2025-04-18 04:33:23', '2025-04-18 04:33:23'),
	(4, 1, 'sadfasfdasdf', '<p>sdfasdfasdfasdfas</p>\r\n<p>asfdasdfasdfasfd</p>\r\n<p>&nbsp;</p>\r\n<p>asdfasdfasdf</p>\r\n<p>asfdasdfasdf</p>\r\n<p>asdfasdfasdf</p>\r\n<p>asdfadsfasdf</p>\r\n<p>asfdasdfasdf</p>\r\n<p>asdfasdfasdf</p>\r\n<p>asfdadsfasdf</p>\r\n<p>&nbsp;</p>', '2025-04-18 04:33:58', '2025-04-18 04:33:58'),
	(7, 1, 'ㅇㅇㅇㅇ', '<p>ㅇㅇㅇㅇㅇㅇ</p>', '2025-04-18 05:59:41', '2025-04-18 05:59:41'),
	(8, 1, 'ㅇㅇㅇ', '<p>ㅇㅇㅇ<img src="../uploads/e5cd3b4d-3e29-4d0c-ab10-4506fdf07b8e.png" alt="" width="559" height="279"></p>', '2025-04-18 06:19:27', '2025-04-18 06:19:27'),
	(9, 1, 'ㅇㅇㅇㅇㅇ', '<p>ㅇㅇㅇㅇ<img src="../uploads/f8b32c6e-cfef-4529-b973-d2d56cc5bb99.png" alt="" width="258" height="259"></p>', '2025-04-18 06:19:55', '2025-04-18 06:19:55'),
	(10, 1, 'ㅇㄴㄴㅇㄹㄴㅇㄹ', '<p>ㄴㅁㅇㄻㄴㅇㄻㄴㅇㄻㄴ</p>', '2025-04-18 06:20:23', '2025-04-18 06:20:23'),
	(11, 1, '111111111111', '<p>11111111111111</p>\r\n<p>&nbsp;</p>\r\n<p>&nbsp;</p>\r\n<p><img src="../uploads/90674481-a49d-446e-8074-3ceaec5523ff.png" alt="" width="258" height="259"></p>', '2025-04-18 06:20:56', '2025-04-18 06:20:56'),
	(12, 1, 'ㄴㅁㅇㄻㄴㅇㄻㄴㄹㅇ', '<p>ㄴㅇㄹㄴㅁㅇㄻㄴㄹㅇ<img src="../uploads/237f5350-a16c-4e6d-91e7-60a0b894e7c3.png" alt="" width="258" height="259"></p>', '2025-04-18 06:22:30', '2025-04-18 06:22:30'),
	(13, 1, '1111111111111', '<p>111111111111</p>', '2025-04-18 06:23:25', '2025-04-18 06:23:25'),
	(14, 1, '2222222', '<p>2222222222222</p>', '2025-04-18 06:23:58', '2025-04-18 06:23:58'),
	(15, 1, '3333', '<p><img src="../uploads/c552aa14-d0d4-43b2-b792-ea7a0b923541.png" alt="" width="319" height="320"></p>', '2025-04-18 06:26:31', '2025-04-18 06:26:31'),
	(16, 1, '44444', '<p><img src="../uploads/6199536d-6bd2-4b93-9e9a-e2943fbb4bc6.png" alt="" width="273" height="136"></p>', '2025-04-18 06:27:07', '2025-04-18 06:27:07');

-- 테이블 blog_db.post_views 구조 내보내기
CREATE TABLE IF NOT EXISTS `post_views` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `post_id` bigint(20) unsigned NOT NULL,
  `viewed_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `ip_address` varchar(45) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 테이블 데이터 blog_db.post_views:~0 rows (대략적) 내보내기
DELETE FROM `post_views`;

-- 테이블 blog_db.users 구조 내보내기
CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint(20) unsigned NOT NULL AUTO_INCREMENT,
  `kakao_id` bigint(20) NOT NULL,
  `nickname` varchar(100) DEFAULT NULL,
  `email` varchar(255) DEFAULT NULL,
  `profile_image` varchar(512) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`id`),
  UNIQUE KEY `kakao_id` (`kakao_id`)
) ENGINE=InnoDB AUTO_INCREMENT=2 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 테이블 데이터 blog_db.users:~1 rows (대략적) 내보내기
DELETE FROM `users`;
INSERT INTO `users` (`id`, `kakao_id`, `nickname`, `email`, `profile_image`, `created_at`) VALUES
	(1, 4221796599, 'SH', 'sh.yang@kakao.com', NULL, '2025-04-18 02:37:01');

