-- MySQL dump 10.11
--
-- Host: localhost    Database: resman2
-- ------------------------------------------------------
-- Server version	5.0.77-log

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `fluid`
--

DROP TABLE IF EXISTS `fluid`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `fluid` (
  `fluid_id` int(10) unsigned NOT NULL auto_increment,
  `fluid` varchar(20) NOT NULL default '' COMMENT '全角文字を入力しないこと',
  `fluid_zen` varchar(20) NOT NULL default '' COMMENT 'なるだけ全角文字のみ入力すること',
  `fluid_order` int(10) NOT NULL,
  PRIMARY KEY  (`fluid_id`),
  UNIQUE KEY `fluid_id` (`fluid_id`),
  UNIQUE KEY `fluid` (`fluid`),
  UNIQUE KEY `fluid_zen` (`fluid_zen`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `fluid`
--

LOCK TABLES `fluid` WRITE;
/*!40000 ALTER TABLE `fluid` DISABLE KEYS */;
INSERT INTO `fluid` VALUES
	  (1, 'oil'         , '原油'          , 100)
	, (2, 'gas'         , 'ガス'          , 200)
	, (3, 'condensate'  , 'コンデンセート', 300)
	, (4, 'injected gas', '圧入ガス'      , 400)
	, (5, 'water'       , '水'            , 500)
	;
/*!40000 ALTER TABLE `fluid` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `base_unit`
--

DROP TABLE IF EXISTS `base_unit`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `base_unit` (
  `base_unit_id` int(10) unsigned NOT NULL auto_increment,
  `base_unit` varchar(40) NOT NULL,
  PRIMARY KEY  (`base_unit_id`),
  UNIQUE KEY `unique_base_unit_1` (`base_unit_id`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `base_unit`
--

LOCK TABLES `base_unit` WRITE;
/*!40000 ALTER TABLE `base_unit` DISABLE KEYS */;
INSERT INTO `base_unit` VALUES
	  (1, 'KL' )
	, (2, 'm3' )
	, (3, 'STB')
	, (4, 'SCF')
	;
/*!40000 ALTER TABLE `base_unit` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `unit`
--

DROP TABLE IF EXISTS `unit`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `unit` (
  `unit_id` int(10) unsigned NOT NULL auto_increment,
  `unit` varchar(40) NOT NULL default '' COMMENT '全角文字を入力しないこと',
  `unit_zen` varchar(40) default NULL,
  `base_unit_id` int(10) unsigned default NULL,
  `unit_order` int(10) unsigned NOT NULL default '1' COMMENT '次数、位数などのオーダー（順序ではなく）',
  PRIMARY KEY  (`unit_id`),
  UNIQUE KEY `unit_id` (`unit_id`),
  UNIQUE KEY `unit` (`unit`),
  UNIQUE KEY `unique_unit_1` (`base_unit_id`,`unit_order`),
  CONSTRAINT `FK_unit_1` FOREIGN KEY (`base_unit_id`) REFERENCES `base_unit` (`base_unit_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=8 DEFAULT CHARSET=utf8 COMMENT='unit, unit_zen には液体、ガス両方の単位を明記';
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `unit`
--

LOCK TABLES `unit` WRITE;
/*!40000 ALTER TABLE `unit` DISABLE KEYS */;
INSERT INTO `unit` VALUES
	  (1, 'KL'      , 'KL'    , 1, 1)
	, (2, '10**3 m3', '千m3'  , 2, 1000)
	, (3, '10**3 KL', '千KL'  , 1, 1000)
	, (4, '10**6 m3', '百万m3', 2, 1000000)
	, (5, 'm3'      , 'm3'    , 2, 1)
	, (6, 'STB'     , 'STB'   , 3, 1)
	, (7, 'SCF'     , 'SCF'   , 4, 1)
	;
/*!40000 ALTER TABLE `unit` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `field`
--

DROP TABLE IF EXISTS `field`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `field` (
  `field_id` int(10) unsigned NOT NULL auto_increment,
  `field` varchar(40) NOT NULL default '' COMMENT '全角文字を入力しないこと',
  `field_zen` varchar(40) NOT NULL default '' COMMENT 'なるだけ全角文字のみ入力すること',
  `date_field_aban` date default NULL COMMENT '採収終了となった日付',
  `date_added` date default NULL,
  `date_removed` date default NULL,
  `field_north` int(10) unsigned NOT NULL default '0' COMMENT '北に位置するほど小さい値になる',
  PRIMARY KEY  (`field_id`),
  UNIQUE KEY `field_id` (`field_id`),
  UNIQUE KEY `field` (`field`)
) ENGINE=InnoDB AUTO_INCREMENT=50 DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `field`
--

LOCK TABLES `field` WRITE;
/*!40000 ALTER TABLE `field` DISABLE KEYS */;
INSERT INTO `field` VALUES
	  ( 1, 'Yufutsu'        , '勇払'  , NULL, NULL, NULL,  140)
	, ( 3, 'Sarukawa'       , '申川'  , NULL, NULL, NULL,  320)
	, (14, 'Higashi-Niigata', '東新潟', NULL, NULL, NULL,  840)
	, (20, 'Iwafune-Oki'    , '岩船沖', NULL, NULL, NULL, 2100)
	;
/*!40000 ALTER TABLE `field` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reservoir`
--

DROP TABLE IF EXISTS `reservoir`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `reservoir` (
  `reservoir_id` int(10) unsigned NOT NULL auto_increment,
  `reservoir` varchar(40) NOT NULL default '' COMMENT '全角文字を入力しないこと',
  `reservoir_zen` varchar(40) NOT NULL default '' COMMENT 'なるだけ全角文字のみ入力すること',
  `date_rsvr_aban` date default NULL COMMENT '採収終了となった日付',
  `date_added` date default NULL,
  `date_removed` date default NULL,
  `waterflooding` tinyint(1) NOT NULL default '0' COMMENT '水攻中か、どうか',
  `shallower` int(10) unsigned NOT NULL default '0' COMMENT '原則、浅いほど小さい値になる',
  `field_id` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`reservoir_id`),
  UNIQUE KEY `reservoir_id` (`reservoir_id`),
  UNIQUE KEY `reservoir` (`reservoir`,`field_id`),
  UNIQUE KEY `shallower_and_field` (`shallower`,`field_id`),
  KEY `field_id` (`field_id`),
  CONSTRAINT `reservoir_ibfk_1` FOREIGN KEY (`field_id`) REFERENCES `field` (`field_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=163 DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `reservoir`
--

LOCK TABLES `reservoir` WRITE;
/*!40000 ALTER TABLE `reservoir` DISABLE KEYS */;
INSERT INTO `reservoir` VALUES
	  (  1, 'Yufutsu'      , '勇払'           , NULL, NULL, NULL, 0, 100, 1)
	, (  3, '1(AB Block)'  , '1(ABブロック)'  , NULL, NULL, NULL, 0, 100, 3)
	, (  4, '2ab(AB Block)', '2ab(ABブロック)', NULL, NULL, NULL, 1, 110, 3)
	, ( 77, '2900mA'       , '2900mA'         , NULL, NULL, '2007-12-31', 0, 200, 14)
	, ( 78, '2900mA3'      , '2900mA3'        , NULL, NULL, '2007-12-31', 0, 210, 14)
	, ( 79, '2900mA4'      , '2900mA4'        , NULL, NULL, '2007-12-31', 0, 220, 14)
	, (108, '1900m'        , '1900m'          , NULL, NULL, NULL, 0, 140, 20)
	, (109, '2000m'        , '2000m'          , NULL, NULL, NULL, 0, 150, 20)
	, (110, '2050m'        , '2050m'          , NULL, NULL, NULL, 0, 160, 20)
	, (111, '2100m'        , '2100m'          , NULL, NULL, NULL, 0, 170, 20)
	;
/*!40000 ALTER TABLE `reservoir` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reserve_header`
--

DROP TABLE IF EXISTS `reserve_header`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `reserve_header` (
  `reserve_id` int(10) unsigned NOT NULL auto_increment,
  `reservoir_id` int(10) unsigned NOT NULL default '0',
  `date_reserve` date NOT NULL default '0000-00-00' COMMENT '鉱量の日付',
  `possibility` int(10) unsigned NOT NULL default '0' COMMENT '実現確率',
  `is_by_completion` tinyint(1) unsigned zerofill NOT NULL default '0' COMMENT '鉱量データとして 0 であれば reserve、1 であれば reserve_by_completion を使う',
  `datetime_input` datetime default NULL COMMENT '入力した日時',
  `username_input` varchar(40) default NULL COMMENT '入力したユーザー名',
  `method_reserve` varchar(20) default NULL,
  `summary` text,
  PRIMARY KEY  (`reserve_id`),
  UNIQUE KEY `reserve_id` (`reserve_id`),
  UNIQUE KEY `id_date_possibility` (`reservoir_id`,`date_reserve`,`possibility`),
  UNIQUE KEY `reservoir_id` (`reservoir_id`,`date_reserve`,`possibility`,`datetime_input`),
  CONSTRAINT `reserve_header_ibfk_1` FOREIGN KEY (`reservoir_id`) REFERENCES `reservoir` (`reservoir_id`) ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=3710 DEFAULT CHARSET=utf8 COMMENT='埋蔵量のヘッダテーブル';
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `reserve_header`
--

LOCK TABLES `reserve_header` WRITE;
/*!40000 ALTER TABLE `reserve_header` DISABLE KEYS */;
INSERT INTO `reserve_header` VALUES
	  (1, 1, '2001-12-31', 90, 0, '2001-03-01 00:00:00', NULL, 'S', ' 減退見直し')
	, (2, 1, '2001-12-31', 50, 0, '2001-03-01 00:00:00', NULL, 'S', NULL)
	;
/*!40000 ALTER TABLE `reserve_header` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `reserve`
--

DROP TABLE IF EXISTS `reserve`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `reserve` (
  `synthetic_id` int(10) unsigned NOT NULL auto_increment,
  `reserve_id` int(10) unsigned NOT NULL,
  `fluid_id` int(10) unsigned NOT NULL default '0',
  `reserve` decimal(15,2) default NULL,
  `unit_id` int(10) unsigned NOT NULL default '0',
  PRIMARY KEY  (`synthetic_id`),
  UNIQUE KEY `reserve_fluid` (`reserve_id`,`fluid_id`),
  KEY `fluid_id` (`fluid_id`),
  KEY `unit_id` (`unit_id`),
  CONSTRAINT `reserve_ibfk_2` FOREIGN KEY (`fluid_id`) REFERENCES `fluid` (`fluid_id`) ON UPDATE CASCADE,
  CONSTRAINT `reserve_ibfk_3` FOREIGN KEY (`unit_id`) REFERENCES `unit` (`unit_id`) ON UPDATE CASCADE,
  CONSTRAINT `reserve_ibfk_4` FOREIGN KEY (`reserve_id`) REFERENCES `reserve_header` (`reserve_id`) ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=6945 DEFAULT CHARSET=utf8;
SET character_set_client = @saved_cs_client;

--
-- Dumping data for table `reserve`
--

LOCK TABLES `reserve` WRITE;
/*!40000 ALTER TABLE `reserve` DISABLE KEYS */;
INSERT INTO `reserve` VALUES
	  (1, 1, 1, '1234.56', 1)
	, (2, 1, 2, '3456.78', 2)
	, (3, 2, 1, '5678.90', 1)
	, (4, 2, 2, '7890.12', 2)
	;
/*!40000 ALTER TABLE `reserve` ENABLE KEYS */;
UNLOCK TABLES;

-- Dump completed on 2010-03-16  6:59:14
