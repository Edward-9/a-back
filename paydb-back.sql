--
-- PostgreSQL database dump
--

-- Dumped from database version 14.2
-- Dumped by pg_dump version 14.2

-- Started on 2023-09-04 22:44:26

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 15 (class 2615 OID 30381)
-- Name: 2can; Type: SCHEMA; Schema: -; Owner: andrey
--

CREATE SCHEMA "2can";


ALTER SCHEMA "2can" OWNER TO andrey;

--
-- TOC entry 12 (class 2615 OID 31732)
-- Name: ataxi_transfer; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ataxi_transfer;


ALTER SCHEMA ataxi_transfer OWNER TO postgres;

--
-- TOC entry 13 (class 2615 OID 29061)
-- Name: common; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA common;


ALTER SCHEMA common OWNER TO postgres;

--
-- TOC entry 5 (class 2615 OID 29062)
-- Name: ekassa; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA ekassa;


ALTER SCHEMA ekassa OWNER TO postgres;

--
-- TOC entry 10 (class 2615 OID 29063)
-- Name: mytosb; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA mytosb;


ALTER SCHEMA mytosb OWNER TO postgres;

--
-- TOC entry 9 (class 2615 OID 29064)
-- Name: reports; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA reports;


ALTER SCHEMA reports OWNER TO postgres;

--
-- TOC entry 8 (class 2615 OID 29065)
-- Name: user; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA "user";


ALTER SCHEMA "user" OWNER TO postgres;

--
-- TOC entry 403 (class 1255 OID 30395)
-- Name: f_syspay(json); Type: FUNCTION; Schema: 2can; Owner: postgres
--

CREATE FUNCTION "2can".f_syspay(x_json json) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xans JSON default '{"ans":"ok"}' ;
	--input data:
	--{
    --}
BEGIN
	INSERT INTO "2can".syspay (json_inside) VALUES (x_json) ;
    RETURN xans;
END;
--output data:
--{"ans": "ok"}
$$;


ALTER FUNCTION "2can".f_syspay(x_json json) OWNER TO postgres;

--
-- TOC entry 406 (class 1255 OID 31483)
-- Name: f_tr_payment(); Type: FUNCTION; Schema: 2can; Owner: postgres
--

CREATE FUNCTION "2can".f_tr_payment() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		xdata JSON; 
		xpaymerch JSON; 
		xjsonfirm JSON;
		xjsoncomm JSON;
		xlogin JSON;
		xmerch JSON;
	  xtarif JSON; 
		xekassa JSON;
		xproducts JSON;
		xbillid INTEGER;
		xcommparam INTEGER;
		xyear INTEGER;
		xidmerch INTEGER;
		xsum NUMERIC(10,2);
		xratio NUMERIC(10,2);
		xidtarif INTEGER;
		xnewid INTEGER;
		xfirm CHAR(6);
		xidlogin CHAR(10);
		xprivilege VARCHAR;
		xamount VARCHAR;
		xdatetime VARCHAR;
		xemail VARCHAR;
		xphone VARCHAR;
		xchannel VARCHAR;
		xmid VARCHAR;
BEGIN 
		--SELECT NEW.json_inside,NEW.json_inside ->> 'principal',(NEW.json_inside ->> 'amount')::integer,NEW.id_paybank,NEW.json_inside ->> 'datetime',
		--NEW.json_inside ->> 'phone_customer',NEW.json_inside ->> 'email_customer',NEW.json_inside -> 'products',NEW.json_inside -> 'merch' 
		--INTO xdata,xfirm,xamount,xbillid,xdatetime,xphone,xemail,xproducts,xidmerch FROM mytosb.syspay; 
		SELECT json_inside,json_inside ->> 'MID',(json_inside ->> 'Amount')::numeric,"id",json_inside ->> 'PaidAt',
		json_inside -> 'Description' 
		INTO xdata,xmid,xamount,xbillid,xdatetime,xproducts FROM "2can".syspay WHERE "id" = 115; 
		SELECT accesuaries ->> 'account' INTO xprivilege FROM "2can".merchant_tap2go WHERE mid = xmid;
		xyear := LEFT(xdatetime,4)::integer;
		xfirm := LEFT(xprivilege,6);
		xdata := xdata::jsonb || jsonb_build_object('id_paybank',xbillid);
		SELECT fljson_firm,fljson_firm ->> 'login',idcommparam INTO xjsonfirm,xidlogin,xcommparam
		FROM common.firmservice WHERE idfirm = xfirm;
		SELECT json_commparam INTO xjsoncomm FROM common.commparam WHERE idcommparam = xcommparam AND common.commparam."enable" = 1;
		SELECT attributies INTO xlogin FROM auth.users WHERE login_master = xidlogin;
		SELECT syspay_merch INTO xidmerch FROM "2can".merchant_tap2go WHERE mid = xmid;
		SELECT accesuaries,(accesuaries ->> 'format_amount')::numeric INTO xmerch,xratio FROM common.merchant WHERE idmerch = xidmerch;
		xsum := (xamount::numeric * xratio::numeric)::numeric(10,2);
		
		SELECT common.tranztarif."Tarif" INTO xidtarif 
		FROM common.tranztarif JOIN common.breakesum ON (common.tranztarif."Breakesum" = common.breakesum.idbreake) 
		WHERE common.tranztarif."Firm" = xfirm AND common.tranztarif."Syspay" = xidmerch AND common.tranztarif."Enable" = 1 
		AND (xsum < (common.breakesum.json_breakesum ->> 'Maxsum')::numeric AND xsum > (common.breakesum.json_breakesum ->> 'Minsum')::numeric);
		SELECT json_tarif INTO xtarif FROM common.tarif WHERE idtarif = xidtarif;
		xpaymerch := jsonb_build_object('id_order',xdata ->> 'id_order','merch',xidmerch);
		--SELECT ecassa::jsonb INTO xekassa FROM mytosb.info WHERE syspay = xidmerch;
		--SELECT channel_notify INTO xchannel FROM ekassa.ekassa WHERE id_kass = (xekassa -> 'ecassa' ->> 0)::integer;
		
		--INSERT INTO reports.payment(data_json,year,idpaymerch,comm_json,firm_json,merch_json,tarif_json,e_kassa)
		--VALUES (xdata,xyear,xpaymerch,xjsoncomm,(xjsonfirm::jsonb || xlogin::jsonb),xmerch,xtarif,xekassa) 
		--ON CONFLICT DO NOTHING RETURNING qtranz INTO xnewid;
		--PERFORM pg_notify(xchannel,xnewid::text);
		--RETURN NULL;
		RETURN xdata;
END
$$;


ALTER FUNCTION "2can".f_tr_payment() OWNER TO postgres;

--
-- TOC entry 395 (class 1255 OID 31819)
-- Name: f_calc(json); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_calc(xcalc json) RETURNS smallint
    LANGUAGE plpgsql
    AS $$
	DECLARE
		xans JSON;
		xidcalc VARCHAR;
		xerr VARCHAR DEFAULT 'dublicate id_order';
		xamount INTEGER;
		xtarif INTEGER;
		xview_trans INTEGER;
		xarray_length INTEGER;
		i INTEGER;
		xyear INTEGER;
		xsaldo INTEGER DEFAULT 0;
		x_from INTEGER;
		x_to INTEGER;
	--IN:
	--{
	--"login": "web_ataxi",
	--"id_calc": "fhgfhgf-hfhthg-jhgjhv",
	--"count_places": 3,
	--"transfer": [{"from": 9, "to": 4},{"from": 6, "to": 8}],
	--"view_transfer": 2
	--"timestamp": "2023-00-00T00:00"
	--}
	BEGIN
		xidcalc := xcalc::jsonb ->> 'id_calc';
		xyear := LEFT(xcalc::jsonb ->> 'timestamp',4)::integer;
		xarray_length := jsonb_array_length(xcalc::jsonb -> 'transfer');
		xtarif := (xcalc::jsonb ->> 'count_places')::integer;
		xview_trans := (xcalc::jsonb ->> 'view_transfer')::integer; 
		xcalc := xcalc::jsonb - 'id_calc';
		FOR i IN 1..xarray_length LOOP
			x_from := (xcalc::jsonb -> 'transfer' -> i - 1 ->> 'from')::integer;
			x_to := (xcalc::jsonb -> 'transfer' -> i - 1 ->> 'to')::integer;
			SELECT amount INTO xamount FROM ataxi_transfer.price 
			WHERE tarif = xtarif AND view_trans = xview_trans AND (town = x_from OR town = x_to);
			xsaldo := xsaldo + xamount;
		END LOOP;
		xcalc := xcalc::jsonb || jsonb_build_object('xsaldo',xsaldo);
		BEGIN
			INSERT INTO ataxi_transfer.calc_sec (id_calc,"year",data_calc) 
			VALUES (xidcalc,xyear,xcalc);
			EXCEPTION WHEN unique_violation THEN
			xans := jsonb_build_object('err',1,'ans',xerr);
			RETURN xans;
	END;
	RETURN xsaldo;
	END
	--out:
	--{
	--"login": "web_ataxi",
	--"order_id": "1111111111"
	--"principal": "200121",
	--"amount": 0,
	--"phone_customer": "+79000000000",
	--"email_customer": null,
	--"name_customer": null,
	--"flight_train": null,
	--"arrival_datetime": "2023-00-00T00:00",
	--"hotel ": null,
	--"quote": {"adult": 1, "younger": 0, "baby": 0}
	--}
	$$;


ALTER FUNCTION ataxi_transfer.f_calc(xcalc json) OWNER TO postgres;

--
-- TOC entry 397 (class 1255 OID 31820)
-- Name: f_change_point(); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_change_point() RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		xitems JSON DEFAULT '{}';
		xjson JSON;
		xid_region INTEGER;
		xkey VARCHAR;
	BEGIN
	FOR xid_region IN 
	SELECT id_region FROM ataxi_transfer.region
	LOOP
		SELECT "alias" INTO xkey FROM ataxi_transfer.region WHERE id_region = xid_region;
		SELECT jsonb_build_object(xkey,array_to_json(array_agg(jsonb_build_object('value',name_town,'text',name_town,'short_name',short_name)))) 
		INTO xjson FROM ataxi_transfer.town	WHERE ataxi_transfer.town.region = xid_region;
		xitems := xitems::jsonb || xjson::jsonb;
  END LOOP;
  RETURN xitems;
  END
  $$;


ALTER FUNCTION ataxi_transfer.f_change_point() OWNER TO postgres;

--
-- TOC entry 412 (class 1255 OID 31821)
-- Name: f_locat(); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_locat() RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE 
	xitems JSON;
	xjson JSON;
	BEGIN
		SELECT jsonb_build_object('adler',array_to_json(array_agg(jsonb_build_object('value',name_town,'text',name_town,'short_name',short_name)))) 
		INTO xitems FROM ataxi_transfer.town	WHERE ataxi_transfer.town.region = 1;
		SELECT jsonb_build_object('abkhazia',array_to_json(array_agg(jsonb_build_object('value',name_town,'text',name_town,'short_name',short_name)))) 
		INTO xjson FROM ataxi_transfer.town WHERE region = 2;
		xitems := xitems::jsonb || xjson::jsonb;
		
		--SELECT ataxi_transfer.town.name_town AS town,ataxi_transfer.town.short_name AS short_name,
		--ataxi_transfer.region.name_region AS region,ataxi_transfer.region."alias" AS "alias"
    --FROM ataxi_transfer.town JOIN ataxi_transfer.region 
		--ON ataxi_transfer.town.region = ataxi_transfer.region.id_region

  RETURN xitems;
  END
  $$;


ALTER FUNCTION ataxi_transfer.f_locat() OWNER TO postgres;

--
-- TOC entry 398 (class 1255 OID 31822)
-- Name: f_locat1(); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_locat1() RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		xitems JSON DEFAULT '{}';
		xjson JSON;
		xid_region INTEGER;
		xkey VARCHAR;
	BEGIN
	FOR xid_region IN 
	SELECT id_region FROM ataxi_transfer.region
	LOOP
		SELECT "alias" INTO xkey FROM ataxi_transfer.region WHERE id_region = xid_region;
		SELECT jsonb_build_object(xkey,array_to_json(array_agg(jsonb_build_object('value',id_town::text,'text',name_town,'short_name',short_name)))) 
		INTO xjson FROM ataxi_transfer.town	WHERE ataxi_transfer.town.region = xid_region;
		xitems := xitems::jsonb || xjson::jsonb;
  END LOOP;
  RETURN xitems;
  END
  $$;


ALTER FUNCTION ataxi_transfer.f_locat1() OWNER TO postgres;

--
-- TOC entry 399 (class 1255 OID 31823)
-- Name: f_location(); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_location() RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE 
	xitems JSON DEFAULT '{}';
	xjson JSON;
	xid_region INTEGER;
	BEGIN
	FOR xid_region IN 
	SELECT id_region FROM ataxi_transfer.region
	LOOP
		SELECT jsonb_build_object("alias",name_region) INTO xjson 
		FROM ataxi_transfer.region WHERE id_region = xid_region;
		xitems := xitems::jsonb || xjson::jsonb;
	END LOOP;
  RETURN xitems;
  END
  $$;


ALTER FUNCTION ataxi_transfer.f_location() OWNER TO postgres;

--
-- TOC entry 414 (class 1255 OID 31887)
-- Name: f_order(json); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_order(x_json json) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		xid INTEGER;
		xid_calc VARCHAR;
		xlogin VARCHAR;
		xdatetime VARCHAR;
		xjs JSON;
		xid_pay JSON; 
	-- IN:
	--	{
	--        "login": "web_ataxi",
	--				"id_calc": "hgfhdhfh",
	--        "amount": 240000,
	--        "view_transfer": 2,
	--        "count_places": 4,
	--        "quote": {
	--            "adult": 1,
	--            "younger": 0,
	--            "baby": 0,
	--        },
	--        "name_customer": "",
	--        "email_customer": "",
	--        "phone_customer": "+79186222897",
	--        "transfer": [
	--            {"to": 4, "from": 1, "flight_train": "", "hotel": "", "datetime_transfer": "2023-04-03T14:30"},
	--            {"to": 2, "from": 6, "flight_train": "", "hotel": "", "datetime_transfer": "2023-04-03T14:30"}
	--        ],
	--        "timestamp": "2023-04-03T14:30"
	--    }
	BEGIN
		xid_calc := x_json::jsonb ->> 'id_calc';
		xdatetime := x_json::jsonb ->> 'timestamp';
		x_json := x_json::jsonb - 'id_calc' - 'timestamp';
		xlogin := x_json::jsonb ->> 'login';
		BEGIN
			INSERT INTO ataxi_transfer."order"(param,id_calc)
			VALUES (x_json,xid_calc) RETURNING id_order INTO xid;
			EXCEPTION WHEN unique_violation THEN
			SELECT id_order INTO xid FROM ataxi_transfer."order" WHERE id_calc = xid_calc;
			xid_pay := jsonb_build_object('id_order',xid::text,'login_dev',xlogin);
			SELECT json_answer INTO xjs FROM mytosb.syspay WHERE idpay = xid_pay::jsonb;
			xjs := xjs::jsonb || jsonb_build_object('err',1);
		RETURN xjs;
		END;
		x_json := x_json::jsonb || jsonb_build_object('id_order',xid,'datetime',xdatetime);
		xjs := ataxi_transfer.f_syspay(x_json);
    RETURN xjs;
	END;
$$;


ALTER FUNCTION ataxi_transfer.f_order(x_json json) OWNER TO postgres;

--
-- TOC entry 413 (class 1255 OID 31935)
-- Name: f_order1(json); Type: FUNCTION; Schema: ataxi_transfer; Owner: vdskkp
--

CREATE FUNCTION ataxi_transfer.f_order1(x_json json) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		xid INTEGER;
		xid_calc VARCHAR;
		xlogin VARCHAR;
		xdatetime VARCHAR;
		xjs JSON;
		xid_pay JSON; 
		xid_paybank INTEGER;
	-- IN:
	--	{
	--        "login": "web_ataxi",
	--				"id_calc": "hgfhdhfh",
	--        "amount": 240000,
	--        "view_transfer": 2,
	--        "count_places": 4,
	--        "quote": {
	--            "adult": 1,
	--            "younger": 0,
	--            "baby": 0,
	--        },
	--        "name_customer": "",
	--        "email_customer": "",
	--        "phone_customer": "+79186222897",
	--        "transfer": [
	--            {"to": 4, "from": 1, "flight_train": "", "hotel": "", "datetime_transfer": "2023-04-03T14:30"},
	--            {"to": 2, "from": 6, "flight_train": "", "hotel": "", "datetime_transfer": "2023-04-03T14:30"}
	--        ],
	--        "timestamp": "2023-04-03T14:30"
	--    }
	BEGIN
		xid_calc := x_json::jsonb ->> 'id_calc';
		xdatetime := x_json::jsonb ->> 'timestamp';
		x_json := x_json::jsonb - 'id_calc' - 'timestamp';
		xlogin := x_json::jsonb ->> 'login';
		BEGIN
			INSERT INTO ataxi_transfer."order"(param,id_calc)
			VALUES (x_json,xid_calc) RETURNING id_order INTO xid;
			EXCEPTION WHEN unique_violation THEN
			SELECT id_order INTO xid FROM ataxi_transfer."order" WHERE id_calc = xid_calc;
			xid_pay := jsonb_build_object('id_order',xid::text,'login_dev',xlogin);
			SELECT json_answer INTO xjs FROM mytosb.syspay WHERE idpay = xid_pay::jsonb;
			xjs := xjs::jsonb || jsonb_build_object('err',1);
		RETURN xjs;
		END;
		x_json := x_json::jsonb || jsonb_build_object('id_order',xid,'datetime',xdatetime);
		xjs := ataxi_transfer.f_syspay(x_json);
		xid_paybank := xjs::jsonb ->> 'newid';		
		update ataxi_transfer."order" set id_paybank = xid_paybank where id_order = xid;
    RETURN xjs;
	END;
$$;


ALTER FUNCTION ataxi_transfer.f_order1(x_json json) OWNER TO vdskkp;

--
-- TOC entry 405 (class 1255 OID 31897)
-- Name: f_order_id(text); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_order_id(id text) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE
		x_param JSON DEFAULT '{}';
	BEGIN
		SELECT jsonb_build_object('id_order', id_order, 'id_calc', id_calc, 'params', param, 'is_payed', t_syspay."enable", 'sbp', t_syspay.json_answer) into x_param
		FROM ataxi_transfer."order" t_order
		LEFT JOIN mytosb.syspay t_syspay on t_order.id_paybank = t_syspay.id_paybank
		WHERE id_calc = id;
	RETURN x_param;
	END;
$$;


ALTER FUNCTION ataxi_transfer.f_order_id(id text) OWNER TO postgres;

--
-- TOC entry 407 (class 1255 OID 31911)
-- Name: f_order_status(); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_order_status() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	DECLARE
		xjs_idpay JSON;
		xlogin VARCHAR;
		xid_order INTEGER;
BEGIN
  SELECT NEW.idpay INTO xjs_idpay FROM mytosb.syspay; 
	xlogin := xjs_idpay::jsonb ->> 'login_dev';
	IF xlogin = 'web_ataxi' THEN
		xid_order := (xjs_idpay::jsonb ->> 'id_order')::integer;
		UPDATE ataxi_transfer."order" SET "enable" = TRUE WHERE id_order = xid_order;
	END IF;
	RETURN NEW;
END
$$;


ALTER FUNCTION ataxi_transfer.f_order_status() OWNER TO postgres;

--
-- TOC entry 408 (class 1255 OID 31916)
-- Name: f_order_status1(); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_order_status1() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
	DECLARE
		xjs_idpay JSON;
		xlogin VARCHAR;
		xid_order INTEGER;
BEGIN
	SELECT idpay INTO xjs_idpay FROM mytosb.syspay WHERE id_paybank = 516;
	xlogin := xjs_idpay::jsonb ->> 'login_dev';
	IF xlogin = 'web_ataxi' THEN
		xid_order := (xjs_idpay::jsonb ->> 'id_order')::integer;
		UPDATE ataxi_transfer."order" SET "enable" = TRUE WHERE id_order = xid_order;
	END IF;
	RETURN xid_order;
END
$$;


ALTER FUNCTION ataxi_transfer.f_order_status1() OWNER TO postgres;

--
-- TOC entry 410 (class 1255 OID 31850)
-- Name: f_syspay(json); Type: FUNCTION; Schema: ataxi_transfer; Owner: postgres
--

CREATE FUNCTION ataxi_transfer.f_syspay(xjson json) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE 
		xans JSON;
	  x_json JSON;
	  xamount VARCHAR;
		xid_order VARCHAR;
 BEGIN
	SELECT accesuaries::jsonb || xjson::jsonb INTO x_json 
	FROM ataxi_transfer.merch_scheme WHERE idmerch = 1;
	xamount := ((x_json::jsonb ->> 'amount')::numeric(10,2) * 100)::text;
	x_json := jsonb_set(x_json::jsonb,'{products,0,amount_prod}',xamount::jsonb,FALSE);
	x_json := jsonb_set(x_json::jsonb,'{products,0,price}',xamount::jsonb,FALSE);
	xans := mytosb.f_syspay(x_json);
	RETURN xans;
END
$$;


ALTER FUNCTION ataxi_transfer.f_syspay(xjson json) OWNER TO postgres;

--
-- TOC entry 360 (class 1255 OID 29857)
-- Name: f_array(character varying); Type: FUNCTION; Schema: common; Owner: postgres
--

CREATE FUNCTION common.f_array(xarray character varying) RETURNS character varying
    LANGUAGE plpython3u
    AS $$
import json
		
x_array = json.loads(xarray)
x_array = x_array[1]
		
		
return x_array
  $$;


ALTER FUNCTION common.f_array(xarray character varying) OWNER TO postgres;

--
-- TOC entry 364 (class 1255 OID 29707)
-- Name: f_gen_pass_bcript(); Type: FUNCTION; Schema: common; Owner: postgres
--

CREATE FUNCTION common.f_gen_pass_bcript() RETURNS character varying
    LANGUAGE plpython3u
    AS $$
import bcrypt
	
passwd = b'R87hf#98rtbnYtr!'		
salt = bcrypt.gensalt()
hashed = bcrypt.hashpw(passwd,salt)
return hashed
$$;


ALTER FUNCTION common.f_gen_pass_bcript() OWNER TO postgres;

--
-- TOC entry 376 (class 1255 OID 29130)
-- Name: f_timestamp(); Type: FUNCTION; Schema: common; Owner: postgres
--

CREATE FUNCTION common.f_timestamp() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
	DECLARE xdatetime VARCHAR;
	BEGIN
  xdatetime := CURRENT_TIMESTAMP(3) AT time ZONE 'Europe/Moscow';
	RETURN xdatetime;
END
$$;


ALTER FUNCTION common.f_timestamp() OWNER TO postgres;

--
-- TOC entry 390 (class 1255 OID 30138)
-- Name: f_ansclient(json, character); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_ansclient(param json, ans_client character) RETURNS void
    LANGUAGE plpgsql
    AS $$
	DECLARE xanswer JSON;
	DECLARE xyear INTEGER;
	DECLARE xqtranz INTEGER;
 BEGIN
 xyear := (param::jsonb ->> 'year')::integer;
 xqtranz := (param::jsonb ->> 'qtranz')::integer;
 SELECT answer INTO xanswer FROM reports.payment WHERE "year" = xyear AND qtranz = xqtranz;
 xanswer := xanswer::jsonb || jsonb_build_object('ekassa',ans_client);
 UPDATE reports.payment SET answer = xanswer WHERE "year" = xyear AND qtranz = xqtranz;
END
$$;


ALTER FUNCTION ekassa.f_ansclient(param json, ans_client character) OWNER TO postgres;

--
-- TOC entry 383 (class 1255 OID 29856)
-- Name: f_array(character varying); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_array(xarray character varying) RETURNS character varying
    LANGUAGE plpython3u
    AS $$
import json
import hashlib
		
x_array = xarray[0]		
		
		
return x_array
  $$;


ALTER FUNCTION ekassa.f_array(xarray character varying) OWNER TO postgres;

--
-- TOC entry 392 (class 1255 OID 30009)
-- Name: f_businessru_callback(json); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_businessru_callback(x_json_clbk json) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xqtranz VARCHAR;
	DECLARE xid_order VARCHAR;
	DECLARE xcheck_url VARCHAR;
	DECLARE xyear INTEGER;
	DECLARE xurl_callback VARCHAR;
	DECLARE xid_callback VARCHAR DEFAULT 'fiskal_check';
	DECLARE xclient_clbk JSON;
BEGIN
	xqtranz := x_json_clbk::jsonb ->> 'c_num';
	xcheck_url := x_json_clbk::jsonb ->> 'receipt_url';
	xcheck_url := replace(xcheck_url,'\','');
	SELECT data_json ->> 'url_callback',"year" INTO xurl_callback,xyear FROM reports.payment WHERE qtranz::text = xqtranz;
	SELECT data_check ->> 'id_order' INTO xid_order FROM ekassa.ekassa_check WHERE qtranz_payment::text = xqtranz;
	UPDATE ekassa.ekassa_check SET call_back = x_json_clbk WHERE qtranz_payment = xqtranz::integer; 
	xclient_clbk := jsonb_build_object('url_callback',xurl_callback,'client',
	jsonb_build_object('id_callback',xid_callback,'id_order',xid_order,'fiskal_url',xcheck_url),
	'answer',jsonb_build_object('bill',true,'qtranz',xqtranz,'year',xyear));
	RETURN xclient_clbk;
END
$$;


ALTER FUNCTION ekassa.f_businessru_callback(x_json_clbk json) OWNER TO postgres;

--
-- TOC entry 391 (class 1255 OID 30158)
-- Name: f_check_businessru(integer); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_check_businessru(xid integer) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xquery_check JSON;
	DECLARE xquery_kassa JSON;
	DECLARE xdata_check JSON;
	DECLARE xcommand JSON;
	DECLARE xproducts JSON;
	DECLARE xgoods JSON;
	DECLARE xgoods_array JSON;
	DECLARE xagent_data JSON;
	DECLARE xresult_goods JSON DEFAULT '[]';
	DECLARE xsecret VARCHAR;
	DECLARE xidorder VARCHAR;
	DECLARE xcheck_url VARCHAR;
	DECLARE xanswer VARCHAR;
	DECLARE xhash VARCHAR;
	DECLARE xnonce VARCHAR;
	DECLARE xprincipal VARCHAR;
	DECLARE xphone_customer VARCHAR;
	DECLARE xphone VARCHAR;
	DECLARE xid_phone_agent VARCHAR;
	DECLARE xprodtype VARCHAR;
	DECLARE xinn VARCHAR;
	DECLARE xemail VARCHAR;
	DECLARE xname VARCHAR;
	DECLARE xname_prod VARCHAR;
	DECLARE xtoken VARCHAR;
	DECLARE xparam VARCHAR;
	DECLARE xcomission VARCHAR;
	DECLARE xerr VARCHAR DEFAULT 'dublicate qtranz';
	DECLARE xratio NUMERIC (3,2);
	DECLARE xmerch INTEGER;
	DECLARE xsupplier INTEGER;
	DECLARE xlength_array INTEGER;
	DECLARE xidpayment INTEGER;
	DECLARE xcontragent INTEGER;
	DECLARE xekassa INTEGER;
	DECLARE xid_ekassa INTEGER;
	DECLARE xcount_prod INTEGER;
	DECLARE xcount_agent INTEGER;
	DECLARE xyear INTEGER;
	DECLARE i INTEGER;
	DECLARE xamount float;
	DECLARE xcomiss_amount float;
	DECLARE xprice_prod float;
	DECLARE xamount_prod float;
	DECLARE xagent BOOLEAN;
	BEGIN
		SELECT MD5(RANDOM()::text) INTO xnonce;
		xidpayment = xid;
		xyear := (LEFT(common.f_timestamp(),4))::integer;
		SELECT LEFT(data_json ->> 'principal',6),
					 data_json ->> 'phone_customer',
					 data_json ->> 'email_customer',
					 (data_json ->> 'amount')::float,
					 data_json -> 'products',
					 data_json ->> 'id_order',
					 e_kassa #>> '{ecassa,0}'
		INTO xprincipal,xphone_customer,xemail,xamount,xproducts,xidorder,xekassa 
		FROM reports.payment WHERE qtranz = xidpayment;
		xlength_array := jsonb_array_length(xproducts::jsonb);
		xdata_check := jsonb_build_object('ecassa',xekassa,'id_order',xidorder);
		SELECT json_settings ->> 'sec',json_settings ->> 'token',json_settings ->> 'PutCheckUrl',json_settings -> 'PutCheck',json_settings -> 'PutCheck' -> 'command' -> 'goods' 
		INTO xsecret,xtoken,xcheck_url,xquery_check,xgoods_array FROM ekassa.ekassa WHERE id_kass = xekassa;
		SELECT contragent,ekassa ->> 'agent',ekassa ->> 'item_type',ekassa -> 'comiss_agent' ->> 'comission',merchant 
		INTO xcontragent,xagent,xprodtype,xcomission,xmerch FROM mytosb.contracts WHERE firmservice = xprincipal;
		SELECT fljson_firm ->> 'upcomission' INTO xcomiss_amount FROM common.firmservice WHERE idfirm = xprincipal;
		SELECT (accesuaries ->> 'format_amount')::numeric(3,2) INTO xratio FROM common.merchant WHERE idmerch = xmerch;
		xamount := (xamount::numeric(10,2) * xratio)::NUMERIC(10,2);
		FOR i IN 1..xlength_array LOOP
			xcount_prod := xproducts::jsonb -> i-1 ->> 'count';
			xprice_prod := xproducts::jsonb -> i-1 ->> 'price';
			xprice_prod := (xprice_prod * xratio::numeric(3,2))::float;
			xname_prod := xproducts::jsonb -> i-1 ->> 'name_prod';
			xamount_prod := xproducts::jsonb -> i-1 ->> 'amount_prod';
			xamount_prod := (xamount_prod::numeric(10,2) * xratio::numeric(3,2))::float;
			IF xagent = TRUE THEN
				xid_phone_agent := xproducts::jsonb -> i-1 ->> 'supplier_phone';
				SELECT COUNT(contragent) INTO xcount_agent FROM mytosb.contracts WHERE login_phone = xid_phone_agent and merchant = xmerch;
				IF xcount_agent = 0 THEN 
					SELECT contragent INTO xsupplier FROM mytosb.contracts WHERE firmservice = xprincipal;
				ELSE
					SELECT contragent INTO xsupplier FROM mytosb.contracts WHERE login_phone = xid_phone_agent;
				END IF;
				SELECT fljson_privilege ->> 'inn',
						   fljson_privilege ->> 'phone',
					     fljson_privilege ->> 'name'
		    INTO xinn,xphone,xname FROM "user".users WHERE idpriv = xsupplier;
				xagent_data := jsonb_build_object('type',32,'supplier_inn',xinn,'supplier_name',xname,'supplier_phone',xphone);
				xgoods := xgoods_array::jsonb -> 0; 
			  xgoods := xgoods::jsonb - 'sum' - 'name' - 'count' - 'price' - 'agent_info' - 'item_type';
				xgoods := xgoods::jsonb || 
				jsonb_build_object('sum',xamount_prod,'name',xname_prod,'count',xcount_prod,'price',xprice_prod,'item_type',xprodtype,'agent_info',xagent_data);  
		  ELSE
				xgoods := xgoods_array::jsonb -> 0;
				xgoods := xgoods::jsonb - 'sum' - 'name' - 'count' - 'price' - 'agent_info' - 'item_type';
				xgoods := xgoods::jsonb || 
				jsonb_build_object('sum',xamount_prod,'name',xname_prod,'count',xcount_prod,'price',xprice_prod,'item_type',xprodtype);
			END IF;
			xresult_goods := xresult_goods::jsonb || xgoods::jsonb;
		END LOOP; 
		xcomiss_amount := ((xamount - (xamount / (1 + xcomiss_amount)))::numeric(10,2))::float;
		xgoods_array := (xgoods_array::jsonb -> 0) - 'agent_info' - 'sum' - 'name' - 'count' - 'price' - 'item_type';
		xgoods_array := xgoods_array::jsonb || jsonb_build_object('sum',xcomiss_amount,'name',xcomission,'count',1,'price',xcomiss_amount,'item_type',4);
		xresult_goods := xresult_goods::jsonb || xgoods_array::jsonb;
		xcommand := ((xquery_check -> 'command')::jsonb - 'goods' - 'c_num' - 'payed_cashless') || 
		jsonb_build_object('goods',xresult_goods::jsonb,'c_num',xidpayment,'payed_cashless',xamount);
		IF xemail IS NOT NULL THEN
			xcommand := xcommand::jsonb - 'smsEmail54FZ' || jsonb_build_object('smsEmail54FZ',xemail); 
		END IF;
		xquery_check := xquery_check::jsonb - 'command' || jsonb_build_object('nonce',xnonce,'token',xtoken,'command',xcommand::jsonb);
		xanswer := ekassa.f_sort_json(xquery_check,xsecret);
		xparam := SPLIT_PART(xanswer, '~&~', 1);
		xhash := SPLIT_PART(xanswer, '~&~', 2);
		xquery_kassa := json_build_object('check_url',xcheck_url,'hash',xhash);
		xquery_kassa := json_build_array(xquery_kassa,xparam);
		BEGIN	
			INSERT INTO ekassa.ekassa_check (query_check,year,data_check,qtranz_payment) VALUES (xquery_kassa,xyear,xdata_check,xidpayment) RETURNING id_ekassa INTO xid_ekassa; 
			EXCEPTION WHEN unique_violation THEN
				xquery_kassa := jsonb_build_object('err',1,'ans',xerr);
			RETURN xcomiss_amount;
		END;
		UPDATE reports.payment SET ekassa_id = 1 WHERE qtranz = xidpayment; 
	RETURN xquery_kassa;
END
$$;


ALTER FUNCTION ekassa.f_check_businessru(xid integer) OWNER TO postgres;

--
-- TOC entry 385 (class 1255 OID 29583)
-- Name: f_ekassa_business_cron(); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_ekassa_business_cron() RETURNS SETOF integer
    LANGUAGE plpgsql ROWS 100
    AS $$
	BEGIN
	 RETURN QUERY SELECT qtranz FROM reports.payment WHERE ekassa_id = 0 AND (now() - interval '60 SECOND') >= "datetime";
	RETURN;
	END
$$;


ALTER FUNCTION ekassa.f_ekassa_business_cron() OWNER TO postgres;

--
-- TOC entry 387 (class 1255 OID 29584)
-- Name: f_ekassa_businessru_answer(json, bigint); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_ekassa_businessru_answer(xjson json, xid bigint) RETURNS void
    LANGUAGE plpgsql
    AS $$
	DECLARE xqtranz INTEGER;
	BEGIN
  UPDATE ekassa.ekassa_check SET ans_ekassa = xjson::jsonb WHERE qtranz_payment = xid;
END
$$;


ALTER FUNCTION ekassa.f_ekassa_businessru_answer(xjson json, xid bigint) OWNER TO postgres;

--
-- TOC entry 380 (class 1255 OID 29585)
-- Name: f_ekassa_businessru_count_err(); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_ekassa_businessru_count_err() RETURNS integer
    LANGUAGE plpgsql
    AS $$
	DECLARE xcount INTEGER;
	BEGIN
  SELECT COUNT(ekassa_id) INTO xcount FROM reports.payment WHERE ekassa_id = 0 AND (now() - interval '60 SECOND') >= "datetime";
	RETURN xcount;
END
$$;


ALTER FUNCTION ekassa.f_ekassa_businessru_count_err() OWNER TO postgres;

--
-- TOC entry 381 (class 1255 OID 29586)
-- Name: f_ekassa_businessru_getcheck(); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_ekassa_businessru_getcheck(OUT xdata json) RETURNS SETOF json
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY SELECT json_build_object('qtranz',doc_ekassa_businessru.id,'json_data',doc_ekassa_businessru.json_data)
     FROM doc_ekassa_businessru  WHERE doc_ekassa_businessru.status::text = 'new'::text;
    RETURN;
 END;
$$;


ALTER FUNCTION ekassa.f_ekassa_businessru_getcheck(OUT xdata json) OWNER TO postgres;

--
-- TOC entry 388 (class 1255 OID 29587)
-- Name: f_ekassa_businessru_jdata(json, integer, json); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_ekassa_businessru_jdata(xjson json, xxid integer, xtoken json) RETURNS json
    LANGUAGE plpgsql
    AS $$
		DECLARE xappid VARCHAR;
		DECLARE xsec VARCHAR;
		DECLARE xemail VARCHAR DEFAULT '';
		DECLARE xphone VARCHAR DEFAULT '';
    DECLARE xekass INTEGER DEFAULT 2;
		DECLARE xamount VARCHAR;
		DECLARE x_token VARCHAR;
		DECLARE xnonce VARCHAR;
		DECLARE xorder VARCHAR;
    DECLARE xprice VARCHAR;
		DECLARE xcheck JSON;
		DECLARE xsecret JSON;
BEGIN
		SELECT json_settings ->> 'PutCheck',json_settings ->> 'appid',json_settings ->> 'sec'
		INTO xcheck,xappid,xsec FROM ekassa.ekassa WHERE id_kass = xekass;
    xemail := xjson::jsonb ->> 'email';
    xphone := xjson::jsonb ->> 'phone';
    xamount := xjson::jsonb ->> 'amount';
    x_token := xtoken::jsonb ->> 'token';
		xnonce := md5(random()::text);
    xorder := xxid;
    --xcheck := REPLACE(xcheck::json, '@mail', xemail);
    --xcheck := REPLACE(xcheck , '@appid', xappid);
		xcheck := jsonb_set(xcheck::jsonb,'{app_id}',xappid::jsonb,FALSE);
		--xcheck := jsonb_set(xcheck::jsonb,'{command,smsEmail54FZ}',xemail::jsonb,FALSE);
    xcheck := jsonb_set(xcheck::jsonb,'{command,c_num}',xorder::jsonb,FALSE);
    xcheck := jsonb_set(xcheck::jsonb,'{command,goods,0,sum}',xamount::jsonb,FALSE);
    xcheck := jsonb_set(xcheck::jsonb,'{command,goods,0,price}',xamount::jsonb,FALSE);
    xcheck := jsonb_set(xcheck::jsonb,'{command,payed_cashless}',xamount::jsonb,FALSE);
    xsecret := json_build_object('token', x_token, 'nonce', xnonce, 'xsec', xsec);
    --xcheck := xcheck::jsonb || x_token::jsonb;
    RETURN xcheck;
END;
$$;


ALTER FUNCTION ekassa.f_ekassa_businessru_jdata(xjson json, xxid integer, xtoken json) OWNER TO postgres;

--
-- TOC entry 384 (class 1255 OID 29588)
-- Name: f_ekassa_businessru_put_token(json); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_ekassa_businessru_put_token(x_json json) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xekassa  INTEGER DEFAULT 2;
	DECLARE yjson JSON;
	DECLARE zjson JSON;
	DECLARE xtoken VARCHAR;
BEGIN
		xtoken := x_json::jsonb ->> 'token';
		SELECT json_settings - 'token' INTO zjson FROM ekassa.ekassa WHERE id_kass  = xekassa;
		yjson := jsonb_build_object('token',xtoken) || zjson::jsonb;
    UPDATE ekassa.ekassa SET json_settings = yjson WHERE id_kass  = xekassa;
		RETURN yjson;
END;
$$;


ALTER FUNCTION ekassa.f_ekassa_businessru_put_token(x_json json) OWNER TO postgres;

--
-- TOC entry 382 (class 1255 OID 29589)
-- Name: f_ekassa_businessru_sign_token(); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_ekassa_businessru_sign_token() RETURNS json
    LANGUAGE plpgsql
    AS $$
    DECLARE xekass INTEGER DEFAULT 2;
    DECLARE xnonce VARCHAR;
    DECLARE xappid VARCHAR;
    DECLARE xsec VARCHAR;
    DECLARE xmass VARCHAR;
    DECLARE xanswer JSON;
    DECLARE xmd5 VARCHAR;
    DECLARE xurl VARCHAR;
    DECLARE xputurl VARCHAR; 
BEGIN
		xnonce := MD5(random()::text);
    SELECT json_settings ->> 'appid',json_settings ->> 'sec',json_settings ->> 'GetTokenUrl',json_settings ->> 'PutCheckUrl' 
		INTO xappid,xsec,xurl,xputurl FROM ekassa.ekassa WHERE id_kass = xekass;
		xmass := json_build_object('app_id', xappid, 'nonce', xnonce);
		xmd5 := MD5(REPLACE(json_build_object('app_id', xappid, 'nonce', xnonce)::text,' ','') || xsec);
		xanswer := json_build_object('params',xmass::json,'headers',json_build_object('Accept','application/json','sign',xmd5),'url',xurl,'chekurl',xputurl);
	  --Записать в таблицу buisinessru_timestamp
		RETURN xanswer;
END;
$$;


ALTER FUNCTION ekassa.f_ekassa_businessru_sign_token() OWNER TO postgres;

--
-- TOC entry 373 (class 1255 OID 29698)
-- Name: f_sort_json(json, character); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_sort_json(xjson json, xsecret character) RETURNS character varying
    LANGUAGE plpython3u
    AS $$
		import json
		import hashlib
		#import urllib.parse
		
		x_json = json.loads(xjson)
		x_json = dict(sorted(x_json.items()))
		x_json = str(x_json)
		x_json = x_json.replace('\'','\"')
		x_json = x_json.replace(': ',':')
		x_json = x_json.replace(', ',',')
		x_json = x_json.replace('True','true')
		x_json = x_json.replace('://',':\/\/')
		y_json = x_json + xsecret
		sign_query = hashlib.md5(y_json.encode())
		sign_query = sign_query.hexdigest()
		#sign_query = urllib.parse.urlencode(y_json)
		x_json = x_json + "~&~" + sign_query
		return x_json
  $$;


ALTER FUNCTION ekassa.f_sort_json(xjson json, xsecret character) OWNER TO postgres;

--
-- TOC entry 400 (class 1255 OID 30357)
-- Name: f_test(integer); Type: FUNCTION; Schema: ekassa; Owner: postgres
--

CREATE FUNCTION ekassa.f_test(xid integer) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xquery_check JSON;
	DECLARE xquery_kassa JSON;
	DECLARE xdata_check JSON;
	DECLARE xcommand JSON;
	DECLARE xproducts JSON;
	DECLARE xgoods JSON;
	DECLARE xgoods_array JSON;
	DECLARE xagent_data JSON;
	DECLARE xresult_goods JSON DEFAULT '[]';
	DECLARE xsecret VARCHAR;
	DECLARE xidorder VARCHAR;
	DECLARE xcheck_url VARCHAR;
	DECLARE xanswer VARCHAR;
	DECLARE xhash VARCHAR;
	DECLARE xnonce VARCHAR;
	DECLARE xprincipal VARCHAR;
	DECLARE xphone_customer VARCHAR;
	DECLARE xphone VARCHAR;
	DECLARE xid_phone_agent VARCHAR;
	DECLARE xprodtype VARCHAR;
	DECLARE xinn VARCHAR;
	DECLARE xemail VARCHAR;
	DECLARE xname VARCHAR;
	DECLARE xname_prod VARCHAR;
	DECLARE xtoken VARCHAR;
	DECLARE xparam VARCHAR;
	DECLARE xcomission VARCHAR;
	DECLARE xerr VARCHAR DEFAULT 'dublicate qtranz';
	DECLARE xratio NUMERIC (3,2);
	DECLARE xmerch INTEGER;
	DECLARE xsupplier INTEGER;
	DECLARE xlength_array INTEGER;
	DECLARE xidpayment INTEGER;
	DECLARE xcontragent INTEGER;
	DECLARE xekassa INTEGER;
	DECLARE xid_ekassa INTEGER;
	DECLARE xcount_prod INTEGER;
	DECLARE xcount_agent INTEGER;
	DECLARE xyear INTEGER;
	DECLARE i INTEGER;
	DECLARE xamount float;
	DECLARE xcomiss_amount float;
	DECLARE xprice_prod float;
	DECLARE xamount_prod float;
	DECLARE xagent BOOLEAN;
	BEGIN
		SELECT MD5(RANDOM()::text) INTO xnonce;
		xidpayment = xid;
		xyear := (LEFT(common.f_timestamp(),4))::integer;
		SELECT LEFT(data_json ->> 'principal',6),
					 data_json ->> 'phone_customer',
					 data_json ->> 'email_customer',
					 (data_json ->> 'amount')::float,
					 data_json -> 'products',
					 data_json ->> 'id_order',
					 e_kassa #>> '{ecassa,0}'
		INTO xprincipal,xphone_customer,xemail,xamount,xproducts,xidorder,xekassa 
		FROM reports.payment WHERE qtranz = xidpayment;
		xlength_array := jsonb_array_length(xproducts::jsonb);
		xdata_check := jsonb_build_object('ecassa',xekassa,'id_order',xidorder);
		SELECT json_settings ->> 'sec',json_settings ->> 'token',json_settings ->> 'PutCheckUrl',json_settings -> 'PutCheck',
		json_settings -> 'PutCheck' -> 'command' -> 'goods' 
		INTO xsecret,xtoken,xcheck_url,xquery_check,xgoods_array FROM ekassa.ekassa WHERE id_kass = xekassa;
		SELECT contragent,ekassa ->> 'agent',ekassa ->> 'item_type',ekassa -> 'comiss_agent' ->> 'comission',merchant 
		INTO xcontragent,xagent,xprodtype,xcomission,xmerch FROM mytosb.contracts WHERE firmservice = xprincipal;
		SELECT fljson_firm ->> 'upcomission' INTO xcomiss_amount FROM common.firmservice WHERE idfirm = xprincipal;
		SELECT (accesuaries ->> 'format_amount')::numeric(3,2) INTO xratio FROM common.merchant WHERE idmerch = xmerch;
		xamount := (xamount::numeric(10,2) * xratio)::NUMERIC(10,2);
		FOR i IN 1..xlength_array LOOP
			xcount_prod := xproducts::jsonb -> i-1 ->> 'count';
			xprice_prod := xproducts::jsonb -> i-1 ->> 'price';
			xprice_prod := (xprice_prod * xratio::numeric(3,2))::float;
			xname_prod := xproducts::jsonb -> i-1 ->> 'name_prod';
			xamount_prod := xproducts::jsonb -> i-1 ->> 'amount_prod';
			xamount_prod := (xamount_prod::numeric(10,2) * xratio::numeric(3,2))::float;
			IF xagent = TRUE THEN
				xid_phone_agent := xproducts::jsonb -> i-1 ->> 'supplier_phone';
				SELECT COUNT(contragent) INTO xcount_agent FROM mytosb.contracts WHERE login_phone = xid_phone_agent and merchant = xmerch;
				IF xcount_agent = 0 THEN 
					SELECT contragent INTO xsupplier FROM mytosb.contracts WHERE firmservice = xprincipal;
				ELSE
					SELECT contragent INTO xsupplier FROM mytosb.contracts WHERE login_phone = xid_phone_agent;
				END IF;
				SELECT fljson_privilege ->> 'inn',
						   fljson_privilege ->> 'phone',
					     fljson_privilege ->> 'name'
		    INTO xinn,xphone,xname FROM "user".users WHERE idpriv = xsupplier;
				xagent_data := jsonb_build_object('type',32,'supplier_inn',xinn,'supplier_name',xname,'supplier_phone',xphone);
				xgoods := xgoods_array::jsonb -> 0; 
			  xgoods := xgoods::jsonb - 'sum' - 'name' - 'count' - 'price' - 'agent_info' - 'item_type';
				xgoods := xgoods::jsonb || 
				jsonb_build_object('sum',xamount_prod,'name',xname_prod,'count',xcount_prod,'price',xprice_prod,'item_type',xprodtype,'agent_info',xagent_data);  
		  ELSE
				xgoods := xgoods_array::jsonb -> 0;
				xgoods := xgoods::jsonb - 'sum' - 'name' - 'count' - 'price' - 'agent_info' - 'item_type';
				xgoods := xgoods::jsonb || 
				jsonb_build_object('sum',xamount_prod,'name',xname_prod,'count',xcount_prod,'price',xprice_prod,'item_type',xprodtype);
			END IF;
			xresult_goods := xresult_goods::jsonb || xgoods::jsonb;
		END LOOP; 
		xcomiss_amount := ((xamount - (xamount / (1 + xcomiss_amount)))::numeric(10,2))::float;
		xgoods_array := (xgoods_array::jsonb -> 0) - 'agent_info' - 'sum' - 'name' - 'count' - 'price' - 'item_type';
		xgoods_array := xgoods_array::jsonb || jsonb_build_object('sum',xcomiss_amount,'name',xcomission,'count',1,'price',xcomiss_amount,'item_type',4);
		xresult_goods := xresult_goods::jsonb || xgoods_array::jsonb;
		xcommand := ((xquery_check -> 'command')::jsonb - 'goods' - 'c_num' - 'payed_cashless') || 
		jsonb_build_object('goods',xresult_goods::jsonb,'c_num',xidpayment,'payed_cashless',xamount);
		IF xemail IS NOT NULL THEN
			xcommand := xcommand::jsonb - 'smsEmail54FZ' || jsonb_build_object('smsEmail54FZ',xemail); 
		END IF;
		xquery_check := xquery_check::jsonb - 'command' || jsonb_build_object('nonce',xnonce,'token',xtoken,'command',xcommand::jsonb);
		xanswer := ekassa.f_sort_json(xquery_check,xsecret);
		xparam := SPLIT_PART(xanswer, '~&~', 1);
		xhash := SPLIT_PART(xanswer, '~&~', 2);
		xquery_kassa := json_build_object('check_url',xcheck_url,'hash',xhash);
		xquery_kassa := json_build_array(xquery_kassa,xparam);
		BEGIN	
			INSERT INTO ekassa.ekassa_check (query_check,year,data_check,qtranz_payment) VALUES (xquery_kassa,xyear,xdata_check,xidpayment) RETURNING id_ekassa INTO xid_ekassa; 
			EXCEPTION WHEN unique_violation THEN
				xquery_kassa := jsonb_build_object('err',1,'ans',xerr);
			RETURN xresult_goods;
		END;
		UPDATE reports.payment SET ekassa_id = 1 WHERE qtranz = xidpayment; 
	RETURN xresult_goods;
END
$$;


ALTER FUNCTION ekassa.f_test(xid integer) OWNER TO postgres;

--
-- TOC entry 393 (class 1255 OID 29383)
-- Name: f_ansbank(json, integer); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_ansbank(xjson json, newid integer) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xidpay INTEGER;
	DECLARE xclient JSON;
	DECLARE xtimestamp JSON;
	DECLARE xpay_code JSON;
	DECLARE xcomiss VARCHAR;
	DECLARE xprincipal VARCHAR;
	DECLARE xdescription VARCHAR DEFAULT 'Комиссия сверх суммы заказа составит &%';
	--{
	--"Data": {
		--"image": {
			--"width": 200, 
			--"height": 200, 
			--"content": "qrcode_base64", 
			--"mediaType": "image/png"
			--}, 
		--"qrcId":"AD10004NBI1TU7R69Q6R9EC0E8OIU4QT", 
		--"payload": "https://qr.nspk.ru/AD10004NBI1TU7R69Q6R9EC0E8OIU4QT?type=02&bank=100000000065&sum=1200&cur=RUB&crc=3C45"
		--}, 
--"Meta": {
	--"totalPages": 1
--}, 
--"Links": {
	--"self": "http://enter.tochka.com/sbp/v1.0/qr-code/merchant/MA0000455002/40702810909500013862/044525999"
	--}
--}
	BEGIN
		SELECT json_build_object('client',jsonb_build_object('id_order',json_inside ->> 'id_order','client_id',json_inside ->> 'client_id')),
		json_inside ->> 'principal' INTO xclient,xprincipal FROM mytosb.syspay WHERE id_paybank = newid;
		SELECT (((fljson_firm ->> 'upcomission')::numeric(3,2) * 100)::float)::text INTO xcomiss 
		FROM common.firmservice WHERE idfirm = xprincipal;
		xdescription := REPLACE(xdescription,'&',xcomiss);
		xpay_code := xjson::jsonb -> 'Data' || xclient::jsonb || jsonb_build_object('description',xdescription); 
		xtimestamp := jsonb_build_object('timestamp',common.f_timestamp());
		UPDATE mytosb.syspay SET json_answer = xpay_code::jsonb || xtimestamp::jsonb WHERE id_paybank = newid; 
		xpay_code := xpay_code::jsonb - 'qrcId';
	RETURN xpay_code;
END
$$;


ALTER FUNCTION mytosb.f_ansbank(xjson json, newid integer) OWNER TO postgres;

--
-- TOC entry 402 (class 1255 OID 31862)
-- Name: f_ansclient(json, character); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_ansclient(param json, ans_client character) RETURNS void
    LANGUAGE plpgsql
    AS $$
	DECLARE xyear INTEGER;
	DECLARE xidpay INTEGER;
 BEGIN
 xyear := (param::jsonb ->> 'year')::integer;
 xidpay := (param::jsonb ->> 'id_paybank')::integer;
 UPDATE reports.payment SET answer = jsonb_build_object('bank',ans_client) 
 WHERE "year" = xyear AND (data_json ->> 'id_paybank')::integer = xidpay;
END
$$;


ALTER FUNCTION mytosb.f_ansclient(param json, ans_client character) OWNER TO postgres;

--
-- TOC entry 375 (class 1255 OID 29385)
-- Name: f_api_users(character); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_api_users(xlogin character) RETURNS json
    LANGUAGE plpgsql
    AS $$
    DECLARE xvalue json;
	BEGIN
	SELECT json_build_object('key',"id_users",'password',"pass") INTO xvalue FROM mytosb.users WHERE id_users = xlogin;
	RETURN xvalue;
	END;
$$;


ALTER FUNCTION mytosb.f_api_users(xlogin character) OWNER TO postgres;

--
-- TOC entry 409 (class 1255 OID 31921)
-- Name: f_api_users_d(character); Type: FUNCTION; Schema: mytosb; Owner: vdskkp
--

CREATE FUNCTION mytosb.f_api_users_d(xlogin character) RETURNS text
    LANGUAGE plpgsql
    AS $$
    DECLARE xvalue text;
	BEGIN
	SELECT descriptions::text INTO xvalue FROM mytosb.users WHERE id_users = xlogin;
	RETURN xvalue;
	END;
$$;


ALTER FUNCTION mytosb.f_api_users_d(xlogin character) OWNER TO vdskkp;

--
-- TOC entry 386 (class 1255 OID 29387)
-- Name: f_callback_bank(json); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_callback_bank(xjson json) RETURNS json
    LANGUAGE plpgsql COST 10
    AS $$
	DECLARE xbillid JSONB;
	DECLARE xcallback JSON;
	DECLARE xans JSON;
	DECLARE xidpay INTEGER;
	DECLARE xidcallback VARCHAR DEFAULT 'pay_result';
	DECLARE xyear VARCHAR;
	DECLARE xurl_callback VARCHAR;
	DECLARE xidorder VARCHAR;
	DECLARE xdescript VARCHAR;
	DECLARE xresult VARCHAR DEFAULT ' перевел(а) Вам ';
	BEGIN
	xbillid := xjson::jsonb -> 'qrcId';
	SELECT id_paybank,json_inside ->> 'id_order',json_inside ->> 'url_callback',LEFT(json_inside ->> 'datetime',4) 
	INTO xidpay,xidorder,xurl_callback,xyear FROM mytosb.syspay WHERE json_answer -> 'qrcId' = xbillid;
	UPDATE mytosb.syspay SET json_callback = xjson WHERE id_paybank = xidpay; 
	UPDATE mytosb.syspay SET "enable" = true WHERE id_paybank = xidpay;
	xdescript := (xjson::jsonb ->> 'payerName')::text || xresult || (xjson::jsonb ->> 'amount')::text || ' руб.';
	xans := jsonb_build_object('client',jsonb_build_object('id_callback',xidcallback,'id_order',xidorder,'descript',xdescript),
	'url_callback',xurl_callback,'answer',jsonb_build_object('id_paybank',xidpay,'year',xyear));
	RETURN xans;
END
$$;


ALTER FUNCTION mytosb.f_callback_bank(xjson json) OWNER TO postgres;

--
-- TOC entry 374 (class 1255 OID 29388)
-- Name: f_heads(); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_heads() RETURNS json
    LANGUAGE plpgsql
    AS $$
  DECLARE xmerch INTEGER DEFAULT 26;
  DECLARE xurl VARCHAR;
	DECLARE xaccess VARCHAR;
	DECLARE xauto VARCHAR;
  DECLARE xurlj JSON;
BEGIN
    SELECT common.merchant.xjson ->> 'GetQrCode' INTO xurl FROM common.merchant WHERE idmerch = xmerch;
    SELECT common.merchant.xjson -> 'token' ->> 'access_token' INTO xaccess FROM common.merchant WHERE idmerch = xmerch;
    xurlj := json_build_object('Url', xurl, 'Authorization', xaccess );
    RETURN xurlj;
END;
$$;


ALTER FUNCTION mytosb.f_heads() OWNER TO postgres;

--
-- TOC entry 379 (class 1255 OID 29389)
-- Name: f_syspay(json); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_syspay(x_json json) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xans JSON;
	DECLARE xidpay JSON;
	DECLARE xmerch INTEGER;
  DECLARE xnewid INTEGER;
	DECLARE xservice INTEGER;
	DECLARE xcomiss NUMERIC(3,2);
  DECLARE xamount VARCHAR;
  DECLARE xaccount VARCHAR;
	DECLARE xerr VARCHAR DEFAULT 'dublicate id_order';
	DECLARE xtimestamp VARCHAR;
	--input data:
	--{
  --"login_dev": "uptaxi",
	--"url_callback": "https:.......", 
  --"id_order": "11a5ce1b-336a-11ed-a8af-b4d5bd9a0as",
  --"amount": 100,
  --"phone_ customer": "+79101234567",
  --"email_customer": "mail@mail.ru",
  --"datetime": "2023-02-17T12:13:30",
  --"principal": "200190",
  --"products": 
  --[
  --{
  --"name_prod": "pizza", "unit": "1","count": 1, "price": 100,"amount_prod": 10000
  --},
	--{
  --"name_prod": "pizza", "unit": "1","count": 1, "price": 100,"amount_prod": 10000
  --}
  --]
  --}
BEGIN
	xtimestamp := jsonb_build_object('timestamp',common.f_timestamp());
	xidpay := jsonb_build_object('login_dev',x_json::jsonb ->> 'login_dev','id_order',x_json::jsonb ->> 'id_order');
	xaccount := x_json::jsonb ->> 'principal';
	SELECT fljson_firm ->> 'service',fljson_firm ->> 'upcomission' 
	INTO xservice,xcomiss FROM common.firmservice WHERE idfirm = xaccount;
	SELECT syspay INTO xmerch FROM mytosb.info WHERE service = xservice;
	SELECT xjson -> 'DataQrCode' INTO xans FROM common.merchant WHERE idmerch = xmerch;
	xamount := ((x_json::jsonb ->> 'amount')::integer + ((x_json::jsonb ->> 'amount')::integer * xcomiss::numeric(3,2))::integer)::text;
	x_json := jsonb_set(x_json::jsonb,'{amount}',xamount::jsonb,FALSE);
	x_json := x_json::jsonb || xtimestamp::jsonb || jsonb_build_object('merch',xmerch);
	BEGIN
		INSERT INTO mytosb.syspay (json_inside,idpay) VALUES (x_json,xidpay) RETURNING id_paybank INTO xnewid;
		EXCEPTION WHEN unique_violation THEN
			xans := jsonb_build_object('err',1,'ans',xerr);
		RETURN xans;
	END;
	xans := jsonb_set(xans::jsonb,'{Data,amount}',xamount::jsonb,FALSE);
	xans := jsonb_build_object('err',0,'newid',xnewid,'ans',xans) || xtimestamp::jsonb;
	UPDATE mytosb.syspay SET json_tobank = xans WHERE id_paybank = xnewid;	
  RETURN xans;
END;
--output data:
--{
--"Data": {
		--"ttl": 25,  
		--"amount": "0", 
		--"qrcType": "02", 
		--"currency": "RUB", 
		--"sourceName": "atotx", 
		--"imageParams": {
				--"width": 200, 
				--"height": 200, 
				--"mediaType": "image/png"
				--}, 
		--"paymentPurpose": "услуги такси"
		--}
--}
$$;


ALTER FUNCTION mytosb.f_syspay(x_json json) OWNER TO postgres;

--
-- TOC entry 404 (class 1255 OID 30175)
-- Name: f_syspay_transfer(json); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_syspay_transfer(x_json json) RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xans JSON;
	DECLARE xidpay JSON;
	DECLARE xmerch INTEGER;
  DECLARE xnewid INTEGER;
	DECLARE xservice INTEGER;
	DECLARE xcomiss NUMERIC(3,2);
	DECLARE xlogin_dev JSON DEFAULT '{"login_dev": "transfer"}';
	DECLARE xurl_callback VARCHAR DEFAULT NULL;
	DECLARE xprincipal JSON DEFAULT '{"principal": "200220"}';
	DECLARE xproducts JSON DEFAULT '{"products": [{"unit": "шт", "count": 1, "price": 0, "name_prod": "услуги трансфера", "amount_prod": 0, "supplier_phone": "+79409912255"}]}';
  DECLARE xamount VARCHAR;
  DECLARE xaccount VARCHAR;
	DECLARE xerr VARCHAR DEFAULT 'dublicate id_order';
	DECLARE xtimestamp VARCHAR;
	--input data:
	--{
  --"login_dev": "uptaxi",
	--"client_id": "111",
	--"url_callback": "https:.......", 
  --"id_order": "11a5ce1b-336a-11ed-a8af-b4d5bd9a0as",
  --"amount": 100,
  --"phone_ customer": "+79101234567",
  --"email_customer": "mail@mail.ru",
  --"datetime": "2023-02-17T12:13:30",
  --"principal": "200190",
  --"products": 
  --[
  --{
  --"name_prod": "pizza", "unit": "1","count": 1, "price": 100,"amount_prod": 10000
  --},
	--{
  --"name_prod": "pizza", "unit": "1","count": 1, "price": 100,"amount_prod": 10000
  --}
  --]
  --}
BEGIN
	xtimestamp := jsonb_build_object('timestamp',common.f_timestamp());
	xidpay := xlogin_dev::jsonb || jsonb_build_object('id_order',x_json::jsonb ->> 'id_order');
	xaccount := xprincipal::jsonb ->> 'principal';
	SELECT fljson_firm ->> 'service',fljson_firm ->> 'upcomission' 
	INTO xservice,xcomiss FROM common.firmservice WHERE idfirm = xaccount;
	SELECT syspay INTO xmerch FROM mytosb.info WHERE service = xservice;
	SELECT xjson -> 'DataQrCode' INTO xans FROM common.merchant WHERE idmerch = xmerch;
	xamount := ((x_json::jsonb ->> 'amount')::integer + ((x_json::jsonb ->> 'amount')::integer * xcomiss::numeric(3,2))::integer)::text;
	x_json := jsonb_set(x_json::jsonb,'{amount}',xamount::jsonb,FALSE);
	x_json := x_json::jsonb || xtimestamp::jsonb || jsonb_build_object('datetime',common.f_timestamp(),'merch',xmerch) || 
	xidpay::jsonb || xprincipal::jsonb || xproducts::jsonb;
	x_json := jsonb_set(x_json::jsonb,'{products,0,price}',xamount::jsonb,FALSE);
	x_json := jsonb_set(x_json::jsonb,'{products,0,amount_prod}',xamount::jsonb,FALSE);
	BEGIN
		INSERT INTO mytosb.syspay (json_inside,idpay) VALUES (x_json,xidpay) RETURNING id_paybank INTO xnewid;
		EXCEPTION WHEN unique_violation THEN
			xans := jsonb_build_object('err',1,'ans',xerr);
		RETURN xans;
	END;
	xans := jsonb_set(xans::jsonb,'{Data,amount}',xamount::jsonb,FALSE);
	xans := jsonb_build_object('err',0,'newid',xnewid,'ans',xans) || xtimestamp::jsonb;
	UPDATE mytosb.syspay SET json_tobank = xans WHERE id_paybank = xnewid;	
  RETURN xans;
END;
--output data:
--{
--"Data": {
		--"ttl": 25,  
		--"amount": "0", 
		--"qrcType": "02", 
		--"currency": "RUB",  
		--"sourceName": "atotx", 
		--"imageParams": {
				--"width": 200, 
				--"height": 200, 
				--"mediaType": "image/png"
				--}, 
		--"paymentPurpose": "услуги такси"
		--}
--}
$$;


ALTER FUNCTION mytosb.f_syspay_transfer(x_json json) OWNER TO postgres;

--
-- TOC entry 377 (class 1255 OID 29390)
-- Name: f_token_access(json); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_token_access(x_json json) RETURNS void
    LANGUAGE plpgsql
    AS $$
	DECLARE xmerch INTEGER DEFAULT 26;
	DECLARE yjson json;
	DECLARE zjson json;
BEGIN
		SELECT xjson - 'token' INTO zjson FROM common.merchant WHERE idmerch = xmerch;
		yjson := jsonb_build_object('token',x_json) || zjson::jsonb;
    UPDATE common.merchant SET xjson = yjson WHERE idmerch = xmerch;
END;
$$;


ALTER FUNCTION mytosb.f_token_access(x_json json) OWNER TO postgres;

--
-- TOC entry 378 (class 1255 OID 29391)
-- Name: f_token_refresh(); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_token_refresh() RETURNS json
    LANGUAGE plpgsql
    AS $$
	DECLARE xmerch INTEGER DEFAULT 26;
	DECLARE xanswer JSON;
	DECLARE xid VARCHAR;
	DECLARE xsecret json;
	DECLARE xrefresh json;
	DECLARE xref_url json;
BEGIN
    SELECT xjson ->> 'client_id',xjson -> 'client_secret',xjson -> 'refresh_url',xjson -> 'token' -> 'refresh_token'
		INTO xid,xsecret,xref_url,xrefresh
		FROM common.merchant 
		WHERE idmerch = xmerch;
    xanswer := jsonb_build_object('ref_url',xref_url) || 
		jsonb_build_object('json_data',jsonb_build_object('client_id',xid,'client_secret',xsecret,'refresh_token',xrefresh,'grant_type','refresh_token'));
    RETURN xanswer;
END;
$$;


ALTER FUNCTION mytosb.f_token_refresh() OWNER TO postgres;

--
-- TOC entry 389 (class 1255 OID 30209)
-- Name: f_tr_payment(); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_tr_payment() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
	DECLARE xdata JSON; 
	DECLARE xpaymerch JSON; 
	DECLARE xjsonfirm JSON;
	DECLARE xjsoncomm JSON;
	DECLARE xlogin JSON;
	DECLARE xmerch JSON;
	DECLARE xtarif JSON; 
	DECLARE xekassa JSON;
	DECLARE xproducts JSON;
	DECLARE xbillid INTEGER;
	DECLARE xcommparam INTEGER;
	DECLARE xyear INTEGER;
	DECLARE xamount INTEGER;
	DECLARE xidmerch INTEGER;
	DECLARE xsum NUMERIC(10,2);
	DECLARE xratio NUMERIC(10,2);
	DECLARE xidtarif INTEGER;
	DECLARE xnewid INTEGER;
	DECLARE xfirm CHAR(6);
	DECLARE xidlogin CHAR(10);
  DECLARE xdatetime VARCHAR;
  DECLARE xemail VARCHAR;
  DECLARE xphone VARCHAR;
	DECLARE xchannel VARCHAR;
BEGIN 
		SELECT NEW.json_inside,NEW.json_inside ->> 'principal',(NEW.json_inside ->> 'amount')::integer,NEW.id_paybank,NEW.json_inside ->> 'datetime',
		NEW.json_inside ->> 'phone_customer',NEW.json_inside ->> 'email_customer',NEW.json_inside -> 'products',NEW.json_inside -> 'merch' 
		INTO xdata,xfirm,xamount,xbillid,xdatetime,xphone,xemail,xproducts,xidmerch FROM mytosb.syspay; 
		xyear := LEFT(xdatetime,4)::integer;
		xdata := xdata::jsonb || jsonb_build_object('id_paybank',xbillid);
		SELECT fljson_firm,fljson_firm ->> 'login',idcommparam INTO xjsonfirm,xidlogin,xcommparam
		FROM common.firmservice WHERE idfirm = xfirm;
		SELECT json_commparam INTO xjsoncomm FROM common.commparam WHERE idcommparam = xcommparam AND common.commparam."enable" = 1;
		SELECT attributies INTO xlogin FROM auth.users WHERE login_master = xidlogin;
		SELECT accesuaries,(accesuaries ->> 'format_amount')::numeric INTO xmerch,xratio FROM common.merchant WHERE idmerch = xidmerch;
		xsum := (xamount * xratio)::numeric(10,2);
		SELECT common.tranztarif."Tarif" INTO xidtarif 
		FROM common.tranztarif JOIN common.breakesum ON (common.tranztarif."Breakesum" = common.breakesum.idbreake) 
		WHERE common.tranztarif."Firm" = xfirm AND common.tranztarif."Syspay" = xidmerch AND common.tranztarif."Enable" = 1 
		AND (xsum < (common.breakesum.json_breakesum ->> 'Maxsum')::numeric AND xsum > (common.breakesum.json_breakesum ->> 'Minsum')::numeric);
		SELECT json_tarif INTO xtarif FROM common.tarif WHERE idtarif = xidtarif;
		xpaymerch := jsonb_build_object('id_order',xdata ->> 'id_order','merch',xidmerch);
		SELECT ecassa::jsonb INTO xekassa FROM mytosb.info WHERE syspay = xidmerch;
		SELECT channel_notify INTO xchannel FROM ekassa.ekassa WHERE id_kass = (xekassa -> 'ecassa' ->> 0)::integer;
		BEGIN
			INSERT INTO reports.payment(data_json,year,idpaymerch,comm_json,firm_json,merch_json,tarif_json,e_kassa)
			VALUES (xdata,xyear,xpaymerch,xjsoncomm,(xjsonfirm::jsonb || xlogin::jsonb),xmerch,xtarif,xekassa) 
			ON CONFLICT DO NOTHING RETURNING qtranz INTO xnewid;
		END;
		PERFORM pg_notify(xchannel,xnewid::text);
		RETURN NULL;
END
$$;


ALTER FUNCTION mytosb.f_tr_payment() OWNER TO postgres;

--
-- TOC entry 411 (class 1255 OID 31730)
-- Name: f_tr_payment_test(); Type: FUNCTION; Schema: mytosb; Owner: postgres
--

CREATE FUNCTION mytosb.f_tr_payment_test() RETURNS character varying
    LANGUAGE plpgsql
    AS $$
	DECLARE xdata JSON; 
	DECLARE xpaymerch JSON; 
	DECLARE xjsonfirm JSON;
	DECLARE xjsoncomm JSON;
	DECLARE xlogin JSON;
	DECLARE xmerch JSON;
	DECLARE xtarif JSON; 
	DECLARE xekassa JSON;
	DECLARE xproducts JSON;
	DECLARE xbillid INTEGER;
	DECLARE xcommparam INTEGER;
	DECLARE xyear INTEGER;
	DECLARE xamount INTEGER;
	DECLARE xidmerch INTEGER;
	DECLARE xsum NUMERIC(10,2);
	DECLARE xratio NUMERIC(10,2);
	DECLARE xidtarif INTEGER;
	DECLARE xnewid INTEGER;
	DECLARE xfirm CHAR(6);
	DECLARE xidlogin CHAR(10);
  DECLARE xdatetime VARCHAR;
  DECLARE xemail VARCHAR;
  DECLARE xphone VARCHAR;
	DECLARE xchannel VARCHAR;
BEGIN 
		SELECT json_inside,json_inside ->> 'principal',(json_inside ->> 'amount')::integer,id_paybank,json_inside ->> 'datetime',
		json_inside ->> 'phone_customer',json_inside ->> 'email_customer',json_inside -> 'products',json_inside -> 'merch' 
		INTO xdata,xfirm,xamount,xbillid,xdatetime,xphone,xemail,xproducts,xidmerch FROM mytosb.syspay WHERE id_paybank = 530; 
		xyear := LEFT(xdatetime,4)::integer;
		xdata := xdata::jsonb || jsonb_build_object('id_paybank',xbillid);
		SELECT fljson_firm,fljson_firm ->> 'login',idcommparam INTO xjsonfirm,xidlogin,xcommparam
		FROM common.firmservice WHERE idfirm = xfirm;
		SELECT json_commparam INTO xjsoncomm FROM common.commparam WHERE idcommparam = xcommparam AND common.commparam."enable" = 1;
		SELECT attributies INTO xlogin FROM auth.users WHERE login_master = xidlogin;
		SELECT accesuaries,(accesuaries ->> 'format_amount')::numeric INTO xmerch,xratio FROM common.merchant WHERE idmerch = xidmerch;
		xsum := (xamount * xratio)::numeric(10,2);
		SELECT common.tranztarif."Tarif" INTO xidtarif 
		FROM common.tranztarif JOIN common.breakesum ON (common.tranztarif."Breakesum" = common.breakesum.idbreake) 
		WHERE common.tranztarif."Firm" = xfirm AND common.tranztarif."Syspay" = xidmerch AND common.tranztarif."Enable" = 1 
		AND (xsum < (common.breakesum.json_breakesum ->> 'Maxsum')::numeric AND xsum > (common.breakesum.json_breakesum ->> 'Minsum')::numeric);
		SELECT json_tarif INTO xtarif FROM common.tarif WHERE idtarif = xidtarif;
		xpaymerch := jsonb_build_object('id_order',xdata ->> 'id_order','merch',xidmerch);
		SELECT ecassa::jsonb INTO xekassa FROM mytosb.info WHERE syspay = xidmerch;
		SELECT channel_notify INTO xchannel FROM ekassa.ekassa WHERE id_kass = (xekassa -> 'ecassa' ->> 0)::integer;
		BEGIN
			--INSERT INTO reports.payment(data_json,year,idpaymerch,comm_json,firm_json,merch_json,tarif_json,e_kassa)
			--VALUES (xdata,xyear,xpaymerch,xjsoncomm,(xjsonfirm::jsonb || xlogin::jsonb),xmerch,xtarif,xekassa) 
			--ON CONFLICT DO NOTHING RETURNING qtranz INTO xnewid;
		END;
		--PERFORM pg_notify(xchannel,xnewid::text);
		RETURN xdatetime
		;
END
$$;


ALTER FUNCTION mytosb.f_tr_payment_test() OWNER TO postgres;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 334 (class 1259 OID 31430)
-- Name: merchant_tap2go; Type: TABLE; Schema: 2can; Owner: postgres
--

CREATE TABLE "2can".merchant_tap2go (
    idmerch smallint NOT NULL,
    accesuaries jsonb,
    mid character varying(50),
    syspay_merch integer
);


ALTER TABLE "2can".merchant_tap2go OWNER TO postgres;

--
-- TOC entry 335 (class 1259 OID 31435)
-- Name: merch_idmerch_seq; Type: SEQUENCE; Schema: 2can; Owner: postgres
--

CREATE SEQUENCE "2can".merch_idmerch_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32000
    CACHE 1;


ALTER TABLE "2can".merch_idmerch_seq OWNER TO postgres;

--
-- TOC entry 3316 (class 0 OID 0)
-- Dependencies: 335
-- Name: merch_idmerch_seq; Type: SEQUENCE OWNED BY; Schema: 2can; Owner: postgres
--

ALTER SEQUENCE "2can".merch_idmerch_seq OWNED BY "2can".merchant_tap2go.idmerch;


--
-- TOC entry 328 (class 1259 OID 30386)
-- Name: syspay; Type: TABLE; Schema: 2can; Owner: postgres
--

CREATE TABLE "2can".syspay (
    id integer NOT NULL,
    json_inside jsonb
);


ALTER TABLE "2can".syspay OWNER TO postgres;

--
-- TOC entry 327 (class 1259 OID 30385)
-- Name: syspay_id_paybank_seq; Type: SEQUENCE; Schema: 2can; Owner: postgres
--

CREATE SEQUENCE "2can".syspay_id_paybank_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "2can".syspay_id_paybank_seq OWNER TO postgres;

--
-- TOC entry 3318 (class 0 OID 0)
-- Dependencies: 327
-- Name: syspay_id_paybank_seq; Type: SEQUENCE OWNED BY; Schema: 2can; Owner: postgres
--

ALTER SEQUENCE "2can".syspay_id_paybank_seq OWNED BY "2can".syspay.id;


--
-- TOC entry 343 (class 1259 OID 31740)
-- Name: !location; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer."!location" (
    id integer NOT NULL,
    region character varying(50),
    town text[],
    location json
);


ALTER TABLE ataxi_transfer."!location" OWNER TO postgres;

--
-- TOC entry 357 (class 1259 OID 31827)
-- Name: calc_sec; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.calc_sec (
    id_calc character varying NOT NULL,
    year smallint NOT NULL,
    data_calc jsonb,
    enable boolean DEFAULT false NOT NULL
)
PARTITION BY RANGE (year);


ALTER TABLE ataxi_transfer.calc_sec OWNER TO postgres;

--
-- TOC entry 344 (class 1259 OID 31745)
-- Name: calc_2023; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.calc_2023 (
    id_calc character varying NOT NULL,
    year smallint DEFAULT 2023 NOT NULL,
    data_calc jsonb,
    enable boolean DEFAULT false NOT NULL
);


ALTER TABLE ataxi_transfer.calc_2023 OWNER TO postgres;

--
-- TOC entry 345 (class 1259 OID 31752)
-- Name: calc_2024; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.calc_2024 (
    id_calc character varying NOT NULL,
    year smallint DEFAULT 2024 NOT NULL,
    data_calc jsonb,
    enable boolean DEFAULT false NOT NULL
);


ALTER TABLE ataxi_transfer.calc_2024 OWNER TO postgres;

--
-- TOC entry 346 (class 1259 OID 31759)
-- Name: calc_2025; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.calc_2025 (
    id_calc character varying NOT NULL,
    year smallint DEFAULT 2025 NOT NULL,
    data_calc jsonb,
    enable boolean DEFAULT false NOT NULL
);


ALTER TABLE ataxi_transfer.calc_2025 OWNER TO postgres;

--
-- TOC entry 347 (class 1259 OID 31766)
-- Name: calc_2026; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.calc_2026 (
    id_calc character varying NOT NULL,
    year smallint DEFAULT 2026 NOT NULL,
    data_calc jsonb,
    enable boolean DEFAULT false NOT NULL
);


ALTER TABLE ataxi_transfer.calc_2026 OWNER TO postgres;

--
-- TOC entry 348 (class 1259 OID 31773)
-- Name: calc_2027; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.calc_2027 (
    id_calc character varying NOT NULL,
    year smallint DEFAULT 2027 NOT NULL,
    data_calc jsonb,
    enable boolean DEFAULT false NOT NULL
);


ALTER TABLE ataxi_transfer.calc_2027 OWNER TO postgres;

--
-- TOC entry 349 (class 1259 OID 31780)
-- Name: calc_2028; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.calc_2028 (
    id_calc character varying NOT NULL,
    year smallint DEFAULT 2028 NOT NULL,
    data_calc jsonb,
    enable boolean DEFAULT false NOT NULL
);


ALTER TABLE ataxi_transfer.calc_2028 OWNER TO postgres;

--
-- TOC entry 336 (class 1259 OID 31733)
-- Name: merch_sch_idmerch_seq; Type: SEQUENCE; Schema: ataxi_transfer; Owner: postgres
--

CREATE SEQUENCE ataxi_transfer.merch_sch_idmerch_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32000
    CACHE 1;


ALTER TABLE ataxi_transfer.merch_sch_idmerch_seq OWNER TO postgres;

--
-- TOC entry 350 (class 1259 OID 31787)
-- Name: merch_scheme; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.merch_scheme (
    idmerch smallint DEFAULT nextval('ataxi_transfer.merch_sch_idmerch_seq'::regclass) NOT NULL,
    accesuaries jsonb,
    login character varying(50) NOT NULL
);


ALTER TABLE ataxi_transfer.merch_scheme OWNER TO postgres;

--
-- TOC entry 338 (class 1259 OID 31735)
-- Name: price_idprice_seq; Type: SEQUENCE; Schema: ataxi_transfer; Owner: postgres
--

CREATE SEQUENCE ataxi_transfer.price_idprice_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32000
    CACHE 1;


ALTER TABLE ataxi_transfer.price_idprice_seq OWNER TO postgres;

--
-- TOC entry 352 (class 1259 OID 31799)
-- Name: price; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.price (
    id_price smallint DEFAULT nextval('ataxi_transfer.price_idprice_seq'::regclass) NOT NULL,
    town smallint NOT NULL,
    view_trans smallint NOT NULL,
    tarif smallint NOT NULL,
    amount numeric(10,2)
);


ALTER TABLE ataxi_transfer.price OWNER TO postgres;

--
-- TOC entry 340 (class 1259 OID 31737)
-- Name: tarif_idtarif_seq; Type: SEQUENCE; Schema: ataxi_transfer; Owner: postgres
--

CREATE SEQUENCE ataxi_transfer.tarif_idtarif_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32000
    CACHE 1;


ALTER TABLE ataxi_transfer.tarif_idtarif_seq OWNER TO postgres;

--
-- TOC entry 354 (class 1259 OID 31807)
-- Name: tarif; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.tarif (
    " id_tarif" smallint DEFAULT nextval('ataxi_transfer.tarif_idtarif_seq'::regclass) NOT NULL,
    name_tarif character varying(50),
    view_trans smallint
);


ALTER TABLE ataxi_transfer.tarif OWNER TO postgres;

--
-- TOC entry 341 (class 1259 OID 31738)
-- Name: town_idtown_seq; Type: SEQUENCE; Schema: ataxi_transfer; Owner: postgres
--

CREATE SEQUENCE ataxi_transfer.town_idtown_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32000
    CACHE 1;


ALTER TABLE ataxi_transfer.town_idtown_seq OWNER TO postgres;

--
-- TOC entry 355 (class 1259 OID 31811)
-- Name: town; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.town (
    id_town smallint DEFAULT nextval('ataxi_transfer.town_idtown_seq'::regclass) NOT NULL,
    name_town character varying(150),
    region smallint,
    short_name character varying(10),
    fld_sort integer
);


ALTER TABLE ataxi_transfer.town OWNER TO postgres;

--
-- TOC entry 342 (class 1259 OID 31739)
-- Name: view_idview_seq; Type: SEQUENCE; Schema: ataxi_transfer; Owner: postgres
--

CREATE SEQUENCE ataxi_transfer.view_idview_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32000
    CACHE 1;


ALTER TABLE ataxi_transfer.view_idview_seq OWNER TO postgres;

--
-- TOC entry 356 (class 1259 OID 31815)
-- Name: view_transfer; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.view_transfer (
    id_view smallint DEFAULT nextval('ataxi_transfer.view_idview_seq'::regclass) NOT NULL,
    view_name character varying(25)
);


ALTER TABLE ataxi_transfer.view_transfer OWNER TO postgres;

--
-- TOC entry 358 (class 1259 OID 31898)
-- Name: mv_tariffs; Type: MATERIALIZED VIEW; Schema: ataxi_transfer; Owner: vdskkp
--

CREATE MATERIALIZED VIEW ataxi_transfer.mv_tariffs AS
 SELECT price.id_price,
    price.town AS id_town,
    town.name_town AS town,
    town.fld_sort,
    price.view_trans AS id_transfer_type,
    view_transfer.view_name AS transfer_type,
    price.tarif AS id_vehicle_size,
    tarif.name_tarif AS vehicle_size,
    price.amount
   FROM (((ataxi_transfer.price
     LEFT JOIN ataxi_transfer.town ON ((price.town = town.id_town)))
     LEFT JOIN ataxi_transfer.view_transfer ON ((price.view_trans = view_transfer.id_view)))
     LEFT JOIN ataxi_transfer.tarif tarif ON ((price.tarif = tarif." id_tarif")))
  ORDER BY price.view_trans, price.tarif, town.fld_sort, town.name_town
  WITH NO DATA;


ALTER TABLE ataxi_transfer.mv_tariffs OWNER TO vdskkp;

--
-- TOC entry 337 (class 1259 OID 31734)
-- Name: order_idorder_seq; Type: SEQUENCE; Schema: ataxi_transfer; Owner: postgres
--

CREATE SEQUENCE ataxi_transfer.order_idorder_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32000
    CACHE 1;


ALTER TABLE ataxi_transfer.order_idorder_seq OWNER TO postgres;

--
-- TOC entry 351 (class 1259 OID 31793)
-- Name: order; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer."order" (
    id_order bigint DEFAULT nextval('ataxi_transfer.order_idorder_seq'::regclass) NOT NULL,
    param jsonb,
    id_calc character varying(50) NOT NULL,
    enable boolean DEFAULT false NOT NULL,
    id_paybank integer
);


ALTER TABLE ataxi_transfer."order" OWNER TO postgres;

--
-- TOC entry 359 (class 1259 OID 31949)
-- Name: order_id_paybank_seq; Type: SEQUENCE; Schema: ataxi_transfer; Owner: postgres
--

CREATE SEQUENCE ataxi_transfer.order_id_paybank_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE ataxi_transfer.order_id_paybank_seq OWNER TO postgres;

--
-- TOC entry 3334 (class 0 OID 0)
-- Dependencies: 359
-- Name: order_id_paybank_seq; Type: SEQUENCE OWNED BY; Schema: ataxi_transfer; Owner: postgres
--

ALTER SEQUENCE ataxi_transfer.order_id_paybank_seq OWNED BY ataxi_transfer."order".id_paybank;


--
-- TOC entry 339 (class 1259 OID 31736)
-- Name: region_idregion_seq; Type: SEQUENCE; Schema: ataxi_transfer; Owner: postgres
--

CREATE SEQUENCE ataxi_transfer.region_idregion_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 32000
    CACHE 1;


ALTER TABLE ataxi_transfer.region_idregion_seq OWNER TO postgres;

--
-- TOC entry 353 (class 1259 OID 31803)
-- Name: region; Type: TABLE; Schema: ataxi_transfer; Owner: postgres
--

CREATE TABLE ataxi_transfer.region (
    id_region smallint DEFAULT nextval('ataxi_transfer.region_idregion_seq'::regclass) NOT NULL,
    name_region character varying(50),
    alias character varying(10)
);


ALTER TABLE ataxi_transfer.region OWNER TO postgres;

--
-- TOC entry 279 (class 1259 OID 29075)
-- Name: banks; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.banks (
    bik character(9) NOT NULL,
    name_bank character varying(50)
);


ALTER TABLE common.banks OWNER TO postgres;

--
-- TOC entry 280 (class 1259 OID 29078)
-- Name: breakesum; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.breakesum (
    idbreake smallint NOT NULL,
    json_breakesum jsonb
);


ALTER TABLE common.breakesum OWNER TO postgres;

--
-- TOC entry 272 (class 1259 OID 29066)
-- Name: breakesum_idbreake_seq; Type: SEQUENCE; Schema: common; Owner: postgres
--

CREATE SEQUENCE common.breakesum_idbreake_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE common.breakesum_idbreake_seq OWNER TO postgres;

--
-- TOC entry 3340 (class 0 OID 0)
-- Dependencies: 272
-- Name: breakesum_idbreake_seq; Type: SEQUENCE OWNED BY; Schema: common; Owner: postgres
--

ALTER SEQUENCE common.breakesum_idbreake_seq OWNED BY common.breakesum.idbreake;


--
-- TOC entry 281 (class 1259 OID 29083)
-- Name: commparam; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.commparam (
    idcommparam integer NOT NULL,
    enable smallint DEFAULT 1,
    json_commparam jsonb
);


ALTER TABLE common.commparam OWNER TO postgres;

--
-- TOC entry 3341 (class 0 OID 0)
-- Dependencies: 281
-- Name: TABLE commparam; Type: COMMENT; Schema: common; Owner: postgres
--

COMMENT ON TABLE common.commparam IS 'Журнал документов данных отправки запросов о платежах принципалам';


--
-- TOC entry 273 (class 1259 OID 29067)
-- Name: commparam_idcommparam_seq; Type: SEQUENCE; Schema: common; Owner: postgres
--

CREATE SEQUENCE common.commparam_idcommparam_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE common.commparam_idcommparam_seq OWNER TO postgres;

--
-- TOC entry 3343 (class 0 OID 0)
-- Dependencies: 273
-- Name: commparam_idcommparam_seq; Type: SEQUENCE OWNED BY; Schema: common; Owner: postgres
--

ALTER SEQUENCE common.commparam_idcommparam_seq OWNED BY common.commparam.idcommparam;


--
-- TOC entry 305 (class 1259 OID 29516)
-- Name: commun; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.commun (
    idcommun integer NOT NULL,
    "NameComm" character varying(50) NOT NULL,
    "Comment" character varying(250) NOT NULL,
    " template_answer" character varying(255),
    " enable" boolean DEFAULT true
);


ALTER TABLE common.commun OWNER TO postgres;

--
-- TOC entry 3344 (class 0 OID 0)
-- Dependencies: 305
-- Name: TABLE commun; Type: COMMENT; Schema: common; Owner: postgres
--

COMMENT ON TABLE common.commun IS 'views of communications';


--
-- TOC entry 274 (class 1259 OID 29068)
-- Name: commun_idcommun_seq; Type: SEQUENCE; Schema: common; Owner: postgres
--

CREATE SEQUENCE common.commun_idcommun_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE common.commun_idcommun_seq OWNER TO postgres;

--
-- TOC entry 3346 (class 0 OID 0)
-- Dependencies: 274
-- Name: commun_idcommun_seq; Type: SEQUENCE OWNED BY; Schema: common; Owner: postgres
--

ALTER SEQUENCE common.commun_idcommun_seq OWNED BY common.commun.idcommun;


--
-- TOC entry 282 (class 1259 OID 29090)
-- Name: department; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.department (
    id character varying(12) NOT NULL,
    name character varying(250) NOT NULL,
    en_name character varying(250) NOT NULL,
    color character varying(20) NOT NULL
);


ALTER TABLE common.department OWNER TO postgres;

--
-- TOC entry 3347 (class 0 OID 0)
-- Dependencies: 282
-- Name: TABLE department; Type: COMMENT; Schema: common; Owner: postgres
--

COMMENT ON TABLE common.department IS 'Справочник соответствия организаций по договоору с пэйбэрии департаментам ';


--
-- TOC entry 283 (class 1259 OID 29095)
-- Name: firmservice; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.firmservice (
    idfirm character(6) NOT NULL,
    enable integer,
    fljson_firm jsonb,
    idcommparam integer NOT NULL
);


ALTER TABLE common.firmservice OWNER TO postgres;

--
-- TOC entry 284 (class 1259 OID 29100)
-- Name: merchant; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.merchant (
    xjson jsonb,
    idmerch integer NOT NULL,
    accesuaries jsonb,
    " enable" boolean DEFAULT true
);


ALTER TABLE common.merchant OWNER TO postgres;

--
-- TOC entry 275 (class 1259 OID 29069)
-- Name: merchant_idmerch_seq; Type: SEQUENCE; Schema: common; Owner: postgres
--

CREATE SEQUENCE common.merchant_idmerch_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE common.merchant_idmerch_seq OWNER TO postgres;

--
-- TOC entry 3351 (class 0 OID 0)
-- Dependencies: 275
-- Name: merchant_idmerch_seq; Type: SEQUENCE OWNED BY; Schema: common; Owner: postgres
--

ALTER SEQUENCE common.merchant_idmerch_seq OWNED BY common.merchant.idmerch;


--
-- TOC entry 285 (class 1259 OID 29107)
-- Name: organisations; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.organisations (
    "Inn_org" character(12) NOT NULL,
    name_org character varying(50),
    form_org character varying(30),
    service character varying(5)
);


ALTER TABLE common.organisations OWNER TO postgres;

--
-- TOC entry 286 (class 1259 OID 29110)
-- Name: service; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.service (
    id_service character varying(16) NOT NULL,
    enable boolean DEFAULT true NOT NULL,
    json_service jsonb
);


ALTER TABLE common.service OWNER TO postgres;

--
-- TOC entry 276 (class 1259 OID 29070)
-- Name: service_id_service_seq; Type: SEQUENCE; Schema: common; Owner: postgres
--

CREATE SEQUENCE common.service_id_service_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE common.service_id_service_seq OWNER TO postgres;

--
-- TOC entry 3354 (class 0 OID 0)
-- Dependencies: 276
-- Name: service_id_service_seq; Type: SEQUENCE OWNED BY; Schema: common; Owner: postgres
--

ALTER SEQUENCE common.service_id_service_seq OWNED BY common.service.id_service;


--
-- TOC entry 287 (class 1259 OID 29117)
-- Name: tarif; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.tarif (
    idtarif integer NOT NULL,
    enable smallint DEFAULT 1,
    json_tarif jsonb
);


ALTER TABLE common.tarif OWNER TO postgres;

--
-- TOC entry 277 (class 1259 OID 29073)
-- Name: tarif_idtarif_seq; Type: SEQUENCE; Schema: common; Owner: postgres
--

CREATE SEQUENCE common.tarif_idtarif_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE common.tarif_idtarif_seq OWNER TO postgres;

--
-- TOC entry 3356 (class 0 OID 0)
-- Dependencies: 277
-- Name: tarif_idtarif_seq; Type: SEQUENCE OWNED BY; Schema: common; Owner: postgres
--

ALTER SEQUENCE common.tarif_idtarif_seq OWNED BY common.tarif.idtarif;


--
-- TOC entry 278 (class 1259 OID 29074)
-- Name: tranztarif_idtranz_seq; Type: SEQUENCE; Schema: common; Owner: postgres
--

CREATE SEQUENCE common.tranztarif_idtranz_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE common.tranztarif_idtranz_seq OWNER TO postgres;

--
-- TOC entry 288 (class 1259 OID 29123)
-- Name: tranztarif; Type: TABLE; Schema: common; Owner: postgres
--

CREATE TABLE common.tranztarif (
    idtranz integer DEFAULT nextval('common.tranztarif_idtranz_seq'::regclass) NOT NULL,
    "Firm" character varying(6) NOT NULL,
    "Tarif" integer NOT NULL,
    "Syspay" smallint NOT NULL,
    "Breakesum" smallint DEFAULT 1 NOT NULL,
    login character(10) NOT NULL,
    "Enable" integer DEFAULT 1 NOT NULL,
    delay integer DEFAULT 0 NOT NULL
);


ALTER TABLE common.tranztarif OWNER TO postgres;

--
-- TOC entry 3357 (class 0 OID 0)
-- Dependencies: 288
-- Name: TABLE tranztarif; Type: COMMENT; Schema: common; Owner: postgres
--

COMMENT ON TABLE common.tranztarif IS 'список тарифов, используемых для пары: фирма-плат.система';


--
-- TOC entry 307 (class 1259 OID 29579)
-- Name: ekassa_id_ekassa_seq; Type: SEQUENCE; Schema: ekassa; Owner: postgres
--

CREATE SEQUENCE ekassa.ekassa_id_ekassa_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE ekassa.ekassa_id_ekassa_seq OWNER TO postgres;

--
-- TOC entry 316 (class 1259 OID 29685)
-- Name: ekassa; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa (
    id_kass integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    json_settings jsonb,
    org character varying(12),
    provider character varying(50),
    channel_notify character varying(20)
);


ALTER TABLE ekassa.ekassa OWNER TO postgres;

--
-- TOC entry 315 (class 1259 OID 29639)
-- Name: ekassa_check; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa_check (
    id_ekassa integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    query_check jsonb,
    ans_ekassa jsonb,
    call_back jsonb,
    year smallint NOT NULL,
    data_check jsonb,
    qtranz_payment bigint
)
PARTITION BY RANGE (year);


ALTER TABLE ekassa.ekassa_check OWNER TO postgres;

--
-- TOC entry 308 (class 1259 OID 29590)
-- Name: ekassa_2023; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa_2023 (
    id_ekassa integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    query_check jsonb,
    ans_ekassa jsonb,
    call_back jsonb,
    year smallint DEFAULT 2023 NOT NULL,
    data_check jsonb,
    qtranz_payment bigint
);


ALTER TABLE ekassa.ekassa_2023 OWNER TO postgres;

--
-- TOC entry 309 (class 1259 OID 29597)
-- Name: ekassa_2024; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa_2024 (
    id_ekassa integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    query_check jsonb,
    ans_ekassa jsonb,
    call_back jsonb,
    year smallint DEFAULT 2024 NOT NULL,
    data_check jsonb,
    qtranz_payment bigint
);


ALTER TABLE ekassa.ekassa_2024 OWNER TO postgres;

--
-- TOC entry 310 (class 1259 OID 29604)
-- Name: ekassa_2025; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa_2025 (
    id_ekassa integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    query_check jsonb,
    ans_ekassa jsonb,
    call_back jsonb,
    year smallint DEFAULT 2025 NOT NULL,
    data_check jsonb,
    qtranz_payment bigint
);


ALTER TABLE ekassa.ekassa_2025 OWNER TO postgres;

--
-- TOC entry 311 (class 1259 OID 29611)
-- Name: ekassa_2026; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa_2026 (
    id_ekassa integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    query_check jsonb,
    ans_ekassa jsonb,
    call_back jsonb,
    year smallint DEFAULT 2026 NOT NULL,
    data_check jsonb,
    qtranz_payment bigint
);


ALTER TABLE ekassa.ekassa_2026 OWNER TO postgres;

--
-- TOC entry 312 (class 1259 OID 29618)
-- Name: ekassa_2027; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa_2027 (
    id_ekassa integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    query_check jsonb,
    ans_ekassa jsonb,
    call_back jsonb,
    year smallint DEFAULT 2027 NOT NULL,
    data_check jsonb,
    qtranz_payment bigint
);


ALTER TABLE ekassa.ekassa_2027 OWNER TO postgres;

--
-- TOC entry 313 (class 1259 OID 29625)
-- Name: ekassa_2028; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa_2028 (
    id_ekassa integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    query_check jsonb,
    ans_ekassa jsonb,
    call_back jsonb,
    year smallint DEFAULT 2028 NOT NULL,
    data_check jsonb,
    qtranz_payment bigint
);


ALTER TABLE ekassa.ekassa_2028 OWNER TO postgres;

--
-- TOC entry 314 (class 1259 OID 29632)
-- Name: ekassa_2029; Type: TABLE; Schema: ekassa; Owner: postgres
--

CREATE TABLE ekassa.ekassa_2029 (
    id_ekassa integer DEFAULT nextval('ekassa.ekassa_id_ekassa_seq'::regclass) NOT NULL,
    query_check jsonb,
    ans_ekassa jsonb,
    call_back jsonb,
    year smallint DEFAULT 2029 NOT NULL,
    data_check jsonb,
    qtranz_payment bigint
);


ALTER TABLE ekassa.ekassa_2029 OWNER TO postgres;

--
-- TOC entry 291 (class 1259 OID 29138)
-- Name: contracts; Type: TABLE; Schema: mytosb; Owner: postgres
--

CREATE TABLE mytosb.contracts (
    id_tranzservice integer NOT NULL,
    inn_firm character(12),
    bank character(9),
    merchant smallint,
    service smallint,
    ekassa jsonb,
    type_sys character varying(10),
    enable boolean DEFAULT true,
    firmservice character varying(10),
    contragent integer,
    bank_core character(20),
    login_phone character(12)
);


ALTER TABLE mytosb.contracts OWNER TO postgres;

--
-- TOC entry 292 (class 1259 OID 29145)
-- Name: info; Type: TABLE; Schema: mytosb; Owner: postgres
--

CREATE TABLE mytosb.info (
    firm character varying(50),
    inn character varying(12),
    bank character varying(50),
    syspay smallint,
    "type syspay" character varying(50),
    ecassa jsonb,
    service smallint
);


ALTER TABLE mytosb.info OWNER TO postgres;

--
-- TOC entry 293 (class 1259 OID 29150)
-- Name: syspay; Type: TABLE; Schema: mytosb; Owner: postgres
--

CREATE TABLE mytosb.syspay (
    id_paybank integer NOT NULL,
    json_inside jsonb,
    json_tobank jsonb,
    json_answer jsonb,
    json_callback jsonb,
    idpay jsonb NOT NULL,
    enable boolean DEFAULT false NOT NULL
);


ALTER TABLE mytosb.syspay OWNER TO postgres;

--
-- TOC entry 289 (class 1259 OID 29136)
-- Name: syspay_id_paybank_seq; Type: SEQUENCE; Schema: mytosb; Owner: postgres
--

CREATE SEQUENCE mytosb.syspay_id_paybank_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE mytosb.syspay_id_paybank_seq OWNER TO postgres;

--
-- TOC entry 3364 (class 0 OID 0)
-- Dependencies: 289
-- Name: syspay_id_paybank_seq; Type: SEQUENCE OWNED BY; Schema: mytosb; Owner: postgres
--

ALTER SEQUENCE mytosb.syspay_id_paybank_seq OWNED BY mytosb.syspay.id_paybank;


--
-- TOC entry 290 (class 1259 OID 29137)
-- Name: tranzserv_id_tranz_service_seq; Type: SEQUENCE; Schema: mytosb; Owner: postgres
--

CREATE SEQUENCE mytosb.tranzserv_id_tranz_service_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    MAXVALUE 2147483647
    CACHE 1;


ALTER TABLE mytosb.tranzserv_id_tranz_service_seq OWNER TO postgres;

--
-- TOC entry 3366 (class 0 OID 0)
-- Dependencies: 290
-- Name: tranzserv_id_tranz_service_seq; Type: SEQUENCE OWNED BY; Schema: mytosb; Owner: postgres
--

ALTER SEQUENCE mytosb.tranzserv_id_tranz_service_seq OWNED BY mytosb.contracts.id_tranzservice;


--
-- TOC entry 294 (class 1259 OID 29378)
-- Name: users; Type: TABLE; Schema: mytosb; Owner: postgres
--

CREATE TABLE mytosb.users (
    id_users character varying(255) NOT NULL,
    pass character varying(255),
    descriptions character varying(255)
);


ALTER TABLE mytosb.users OWNER TO postgres;

--
-- TOC entry 326 (class 1259 OID 29985)
-- Name: xcount_agent; Type: TABLE; Schema: mytosb; Owner: postgres
--

CREATE TABLE mytosb.xcount_agent (
    count bigint
);


ALTER TABLE mytosb.xcount_agent OWNER TO postgres;

--
-- TOC entry 303 (class 1259 OID 29476)
-- Name: payment; Type: TABLE; Schema: reports; Owner: postgres
--

CREATE TABLE reports.payment (
    qtranz integer NOT NULL,
    year smallint NOT NULL,
    idpaymerch jsonb NOT NULL,
    data_json jsonb,
    answer jsonb DEFAULT '{}'::jsonb,
    comm_json jsonb,
    firm_json jsonb,
    merch_json jsonb,
    tarif_json jsonb,
    e_kassa jsonb,
    ekassa_id bigint DEFAULT 0,
    datetime timestamp(0) without time zone DEFAULT now()
)
PARTITION BY RANGE (year);


ALTER TABLE reports.payment OWNER TO postgres;

--
-- TOC entry 295 (class 1259 OID 29405)
-- Name: payment_qrtanz_seq; Type: SEQUENCE; Schema: reports; Owner: postgres
--

CREATE SEQUENCE reports.payment_qrtanz_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE reports.payment_qrtanz_seq OWNER TO postgres;

--
-- TOC entry 3371 (class 0 OID 0)
-- Dependencies: 295
-- Name: payment_qrtanz_seq; Type: SEQUENCE OWNED BY; Schema: reports; Owner: postgres
--

ALTER SEQUENCE reports.payment_qrtanz_seq OWNED BY reports.payment.qtranz;


--
-- TOC entry 296 (class 1259 OID 29406)
-- Name: payment_2023; Type: TABLE; Schema: reports; Owner: postgres
--

CREATE TABLE reports.payment_2023 (
    qtranz integer DEFAULT nextval('reports.payment_qrtanz_seq'::regclass) NOT NULL,
    year smallint DEFAULT 2023 NOT NULL,
    idpaymerch jsonb NOT NULL,
    data_json jsonb,
    answer jsonb DEFAULT '{}'::jsonb,
    comm_json jsonb,
    firm_json jsonb,
    merch_json jsonb,
    tarif_json jsonb,
    e_kassa jsonb,
    ekassa_id bigint DEFAULT 0,
    datetime timestamp(0) without time zone DEFAULT now()
);


ALTER TABLE reports.payment_2023 OWNER TO postgres;

--
-- TOC entry 297 (class 1259 OID 29416)
-- Name: payment_2024; Type: TABLE; Schema: reports; Owner: postgres
--

CREATE TABLE reports.payment_2024 (
    qtranz integer DEFAULT nextval('reports.payment_qrtanz_seq'::regclass) NOT NULL,
    year smallint DEFAULT 2024 NOT NULL,
    idpaymerch jsonb NOT NULL,
    data_json jsonb,
    answer jsonb DEFAULT '{}'::jsonb,
    comm_json jsonb,
    firm_json jsonb,
    merch_json jsonb,
    tarif_json jsonb,
    e_kassa jsonb,
    ekassa_id bigint DEFAULT 0,
    datetime timestamp(0) without time zone DEFAULT now()
);


ALTER TABLE reports.payment_2024 OWNER TO postgres;

--
-- TOC entry 298 (class 1259 OID 29426)
-- Name: payment_2025; Type: TABLE; Schema: reports; Owner: postgres
--

CREATE TABLE reports.payment_2025 (
    qtranz integer DEFAULT nextval('reports.payment_qrtanz_seq'::regclass) NOT NULL,
    year smallint DEFAULT 2025 NOT NULL,
    idpaymerch jsonb NOT NULL,
    data_json jsonb,
    answer jsonb DEFAULT '{}'::jsonb,
    comm_json jsonb,
    firm_json jsonb,
    merch_json jsonb,
    tarif_json jsonb,
    e_kassa jsonb,
    ekassa_id bigint DEFAULT 0,
    datetime timestamp(0) without time zone DEFAULT now()
);


ALTER TABLE reports.payment_2025 OWNER TO postgres;

--
-- TOC entry 299 (class 1259 OID 29436)
-- Name: payment_2026; Type: TABLE; Schema: reports; Owner: postgres
--

CREATE TABLE reports.payment_2026 (
    qtranz integer DEFAULT nextval('reports.payment_qrtanz_seq'::regclass) NOT NULL,
    year smallint DEFAULT 2026 NOT NULL,
    idpaymerch jsonb NOT NULL,
    data_json jsonb,
    answer jsonb DEFAULT '{}'::jsonb,
    comm_json jsonb,
    firm_json jsonb,
    merch_json jsonb,
    tarif_json jsonb,
    e_kassa jsonb,
    ekassa_id bigint DEFAULT 0,
    datetime timestamp(0) without time zone DEFAULT now()
);


ALTER TABLE reports.payment_2026 OWNER TO postgres;

--
-- TOC entry 300 (class 1259 OID 29446)
-- Name: payment_2027; Type: TABLE; Schema: reports; Owner: postgres
--

CREATE TABLE reports.payment_2027 (
    qtranz integer DEFAULT nextval('reports.payment_qrtanz_seq'::regclass) NOT NULL,
    year smallint DEFAULT 2027 NOT NULL,
    idpaymerch jsonb NOT NULL,
    data_json jsonb,
    answer jsonb DEFAULT '{}'::jsonb,
    comm_json jsonb,
    firm_json jsonb,
    merch_json jsonb,
    tarif_json jsonb,
    e_kassa jsonb,
    ekassa_id bigint DEFAULT 0,
    datetime timestamp(0) without time zone DEFAULT now()
);


ALTER TABLE reports.payment_2027 OWNER TO postgres;

--
-- TOC entry 301 (class 1259 OID 29456)
-- Name: payment_2028; Type: TABLE; Schema: reports; Owner: postgres
--

CREATE TABLE reports.payment_2028 (
    qtranz integer DEFAULT nextval('reports.payment_qrtanz_seq'::regclass) NOT NULL,
    year smallint DEFAULT 2028 NOT NULL,
    idpaymerch jsonb NOT NULL,
    data_json jsonb,
    answer jsonb DEFAULT '{}'::jsonb,
    comm_json jsonb,
    firm_json jsonb,
    merch_json jsonb,
    tarif_json jsonb,
    e_kassa jsonb,
    ekassa_id bigint DEFAULT 0,
    datetime timestamp(0) without time zone DEFAULT now()
);


ALTER TABLE reports.payment_2028 OWNER TO postgres;

--
-- TOC entry 302 (class 1259 OID 29466)
-- Name: payment_2029; Type: TABLE; Schema: reports; Owner: postgres
--

CREATE TABLE reports.payment_2029 (
    qtranz integer DEFAULT nextval('reports.payment_qrtanz_seq'::regclass) NOT NULL,
    year smallint DEFAULT 2029 NOT NULL,
    idpaymerch jsonb NOT NULL,
    data_json jsonb,
    answer jsonb DEFAULT '{}'::jsonb,
    comm_json jsonb,
    firm_json jsonb,
    merch_json jsonb,
    tarif_json jsonb,
    e_kassa jsonb,
    ekassa_id bigint DEFAULT 0,
    datetime timestamp(0) without time zone DEFAULT now()
);


ALTER TABLE reports.payment_2029 OWNER TO postgres;

--
-- TOC entry 304 (class 1259 OID 29500)
-- Name: users; Type: TABLE; Schema: user; Owner: postgres
--

CREATE TABLE "user".users (
    idpriv integer NOT NULL,
    fljson_privilege jsonb,
    gruop_user smallint
);


ALTER TABLE "user".users OWNER TO postgres;

--
-- TOC entry 306 (class 1259 OID 29542)
-- Name: users_idpriv_seq; Type: SEQUENCE; Schema: user; Owner: postgres
--

CREATE SEQUENCE "user".users_idpriv_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE "user".users_idpriv_seq OWNER TO postgres;

--
-- TOC entry 3374 (class 0 OID 0)
-- Dependencies: 306
-- Name: users_idpriv_seq; Type: SEQUENCE OWNED BY; Schema: user; Owner: postgres
--

ALTER SEQUENCE "user".users_idpriv_seq OWNED BY "user".users.idpriv;


--
-- TOC entry 2857 (class 0 OID 0)
-- Name: calc_2023; Type: TABLE ATTACH; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_sec ATTACH PARTITION ataxi_transfer.calc_2023 FOR VALUES FROM ('2023') TO ('2024');


--
-- TOC entry 2858 (class 0 OID 0)
-- Name: calc_2024; Type: TABLE ATTACH; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_sec ATTACH PARTITION ataxi_transfer.calc_2024 FOR VALUES FROM ('2024') TO ('2025');


--
-- TOC entry 2859 (class 0 OID 0)
-- Name: calc_2025; Type: TABLE ATTACH; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_sec ATTACH PARTITION ataxi_transfer.calc_2025 FOR VALUES FROM ('2025') TO ('2026');


--
-- TOC entry 2860 (class 0 OID 0)
-- Name: calc_2026; Type: TABLE ATTACH; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_sec ATTACH PARTITION ataxi_transfer.calc_2026 FOR VALUES FROM ('2026') TO ('2027');


--
-- TOC entry 2861 (class 0 OID 0)
-- Name: calc_2027; Type: TABLE ATTACH; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_sec ATTACH PARTITION ataxi_transfer.calc_2027 FOR VALUES FROM ('2027') TO ('2028');


--
-- TOC entry 2862 (class 0 OID 0)
-- Name: calc_2028; Type: TABLE ATTACH; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_sec ATTACH PARTITION ataxi_transfer.calc_2028 FOR VALUES FROM ('2028') TO ('2029');


--
-- TOC entry 2850 (class 0 OID 0)
-- Name: ekassa_2023; Type: TABLE ATTACH; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_check ATTACH PARTITION ekassa.ekassa_2023 FOR VALUES FROM ('2023') TO ('2024');


--
-- TOC entry 2851 (class 0 OID 0)
-- Name: ekassa_2024; Type: TABLE ATTACH; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_check ATTACH PARTITION ekassa.ekassa_2024 FOR VALUES FROM ('2024') TO ('2025');


--
-- TOC entry 2852 (class 0 OID 0)
-- Name: ekassa_2025; Type: TABLE ATTACH; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_check ATTACH PARTITION ekassa.ekassa_2025 FOR VALUES FROM ('2025') TO ('2026');


--
-- TOC entry 2853 (class 0 OID 0)
-- Name: ekassa_2026; Type: TABLE ATTACH; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_check ATTACH PARTITION ekassa.ekassa_2026 FOR VALUES FROM ('2026') TO ('2027');


--
-- TOC entry 2854 (class 0 OID 0)
-- Name: ekassa_2027; Type: TABLE ATTACH; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_check ATTACH PARTITION ekassa.ekassa_2027 FOR VALUES FROM ('2027') TO ('2028');


--
-- TOC entry 2855 (class 0 OID 0)
-- Name: ekassa_2028; Type: TABLE ATTACH; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_check ATTACH PARTITION ekassa.ekassa_2028 FOR VALUES FROM ('2028') TO ('2029');


--
-- TOC entry 2856 (class 0 OID 0)
-- Name: ekassa_2029; Type: TABLE ATTACH; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_check ATTACH PARTITION ekassa.ekassa_2029 FOR VALUES FROM ('2029') TO ('2030');


--
-- TOC entry 2843 (class 0 OID 0)
-- Name: payment_2023; Type: TABLE ATTACH; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment ATTACH PARTITION reports.payment_2023 FOR VALUES FROM ('2023') TO ('2024');


--
-- TOC entry 2844 (class 0 OID 0)
-- Name: payment_2024; Type: TABLE ATTACH; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment ATTACH PARTITION reports.payment_2024 FOR VALUES FROM ('2024') TO ('2025');


--
-- TOC entry 2845 (class 0 OID 0)
-- Name: payment_2025; Type: TABLE ATTACH; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment ATTACH PARTITION reports.payment_2025 FOR VALUES FROM ('2025') TO ('2026');


--
-- TOC entry 2846 (class 0 OID 0)
-- Name: payment_2026; Type: TABLE ATTACH; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment ATTACH PARTITION reports.payment_2026 FOR VALUES FROM ('2026') TO ('2027');


--
-- TOC entry 2847 (class 0 OID 0)
-- Name: payment_2027; Type: TABLE ATTACH; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment ATTACH PARTITION reports.payment_2027 FOR VALUES FROM ('2027') TO ('2028');


--
-- TOC entry 2848 (class 0 OID 0)
-- Name: payment_2028; Type: TABLE ATTACH; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment ATTACH PARTITION reports.payment_2028 FOR VALUES FROM ('2028') TO ('2029');


--
-- TOC entry 2849 (class 0 OID 0)
-- Name: payment_2029; Type: TABLE ATTACH; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment ATTACH PARTITION reports.payment_2029 FOR VALUES FROM ('2029') TO ('2030');


--
-- TOC entry 2939 (class 2604 OID 31436)
-- Name: merchant_tap2go idmerch; Type: DEFAULT; Schema: 2can; Owner: postgres
--

ALTER TABLE ONLY "2can".merchant_tap2go ALTER COLUMN idmerch SET DEFAULT nextval('"2can".merch_idmerch_seq'::regclass);


--
-- TOC entry 2938 (class 2604 OID 30389)
-- Name: syspay id; Type: DEFAULT; Schema: 2can; Owner: postgres
--

ALTER TABLE ONLY "2can".syspay ALTER COLUMN id SET DEFAULT nextval('"2can".syspay_id_paybank_seq'::regclass);


--
-- TOC entry 2863 (class 2604 OID 29513)
-- Name: breakesum idbreake; Type: DEFAULT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.breakesum ALTER COLUMN idbreake SET DEFAULT nextval('common.breakesum_idbreake_seq'::regclass);


--
-- TOC entry 2864 (class 2604 OID 29086)
-- Name: commparam idcommparam; Type: DEFAULT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.commparam ALTER COLUMN idcommparam SET DEFAULT nextval('common.commparam_idcommparam_seq'::regclass);


--
-- TOC entry 2920 (class 2604 OID 29519)
-- Name: commun idcommun; Type: DEFAULT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.commun ALTER COLUMN idcommun SET DEFAULT nextval('common.commun_idcommun_seq'::regclass);


--
-- TOC entry 2866 (class 2604 OID 29103)
-- Name: merchant idmerch; Type: DEFAULT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.merchant ALTER COLUMN idmerch SET DEFAULT nextval('common.merchant_idmerch_seq'::regclass);


--
-- TOC entry 2869 (class 2604 OID 31421)
-- Name: service id_service; Type: DEFAULT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.service ALTER COLUMN id_service SET DEFAULT nextval('common.service_id_service_seq'::regclass);


--
-- TOC entry 2871 (class 2604 OID 29537)
-- Name: tarif idtarif; Type: DEFAULT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.tarif ALTER COLUMN idtarif SET DEFAULT nextval('common.tarif_idtarif_seq'::regclass);


--
-- TOC entry 2876 (class 2604 OID 29141)
-- Name: contracts id_tranzservice; Type: DEFAULT; Schema: mytosb; Owner: postgres
--

ALTER TABLE ONLY mytosb.contracts ALTER COLUMN id_tranzservice SET DEFAULT nextval('mytosb.tranzserv_id_tranz_service_seq'::regclass);


--
-- TOC entry 2878 (class 2604 OID 29153)
-- Name: syspay id_paybank; Type: DEFAULT; Schema: mytosb; Owner: postgres
--

ALTER TABLE ONLY mytosb.syspay ALTER COLUMN id_paybank SET DEFAULT nextval('mytosb.syspay_id_paybank_seq'::regclass);


--
-- TOC entry 2915 (class 2604 OID 29479)
-- Name: payment qtranz; Type: DEFAULT; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment ALTER COLUMN qtranz SET DEFAULT nextval('reports.payment_qrtanz_seq'::regclass);


--
-- TOC entry 2919 (class 2604 OID 29543)
-- Name: users idpriv; Type: DEFAULT; Schema: user; Owner: postgres
--

ALTER TABLE ONLY "user".users ALTER COLUMN idpriv SET DEFAULT nextval('"user".users_idpriv_seq'::regclass);



--
-- TOC entry 3375 (class 0 OID 0)
-- Dependencies: 335
-- Name: merch_idmerch_seq; Type: SEQUENCE SET; Schema: 2can; Owner: postgres
--

SELECT pg_catalog.setval('"2can".merch_idmerch_seq', 3, true);


--
-- TOC entry 3376 (class 0 OID 0)
-- Dependencies: 327
-- Name: syspay_id_paybank_seq; Type: SEQUENCE SET; Schema: 2can; Owner: postgres
--

SELECT pg_catalog.setval('"2can".syspay_id_paybank_seq', 234, true);


--
-- TOC entry 3377 (class 0 OID 0)
-- Dependencies: 336
-- Name: merch_sch_idmerch_seq; Type: SEQUENCE SET; Schema: ataxi_transfer; Owner: postgres
--

SELECT pg_catalog.setval('ataxi_transfer.merch_sch_idmerch_seq', 1, false);


--
-- TOC entry 3378 (class 0 OID 0)
-- Dependencies: 359
-- Name: order_id_paybank_seq; Type: SEQUENCE SET; Schema: ataxi_transfer; Owner: postgres
--

SELECT pg_catalog.setval('ataxi_transfer.order_id_paybank_seq', 38, true);


--
-- TOC entry 3379 (class 0 OID 0)
-- Dependencies: 337
-- Name: order_idorder_seq; Type: SEQUENCE SET; Schema: ataxi_transfer; Owner: postgres
--

SELECT pg_catalog.setval('ataxi_transfer.order_idorder_seq', 212, true);


--
-- TOC entry 3380 (class 0 OID 0)
-- Dependencies: 338
-- Name: price_idprice_seq; Type: SEQUENCE SET; Schema: ataxi_transfer; Owner: postgres
--

SELECT pg_catalog.setval('ataxi_transfer.price_idprice_seq', 1, false);


--
-- TOC entry 3381 (class 0 OID 0)
-- Dependencies: 339
-- Name: region_idregion_seq; Type: SEQUENCE SET; Schema: ataxi_transfer; Owner: postgres
--

SELECT pg_catalog.setval('ataxi_transfer.region_idregion_seq', 1, false);


--
-- TOC entry 3382 (class 0 OID 0)
-- Dependencies: 340
-- Name: tarif_idtarif_seq; Type: SEQUENCE SET; Schema: ataxi_transfer; Owner: postgres
--

SELECT pg_catalog.setval('ataxi_transfer.tarif_idtarif_seq', 1, false);


--
-- TOC entry 3383 (class 0 OID 0)
-- Dependencies: 341
-- Name: town_idtown_seq; Type: SEQUENCE SET; Schema: ataxi_transfer; Owner: postgres
--

SELECT pg_catalog.setval('ataxi_transfer.town_idtown_seq', 1, false);


--
-- TOC entry 3384 (class 0 OID 0)
-- Dependencies: 342
-- Name: view_idview_seq; Type: SEQUENCE SET; Schema: ataxi_transfer; Owner: postgres
--

SELECT pg_catalog.setval('ataxi_transfer.view_idview_seq', 1, false);


--
-- TOC entry 3385 (class 0 OID 0)
-- Dependencies: 272
-- Name: breakesum_idbreake_seq; Type: SEQUENCE SET; Schema: common; Owner: postgres
--

SELECT pg_catalog.setval('common.breakesum_idbreake_seq', 7, true);


--
-- TOC entry 3386 (class 0 OID 0)
-- Dependencies: 273
-- Name: commparam_idcommparam_seq; Type: SEQUENCE SET; Schema: common; Owner: postgres
--

SELECT pg_catalog.setval('common.commparam_idcommparam_seq', 3, true);


--
-- TOC entry 3387 (class 0 OID 0)
-- Dependencies: 274
-- Name: commun_idcommun_seq; Type: SEQUENCE SET; Schema: common; Owner: postgres
--

SELECT pg_catalog.setval('common.commun_idcommun_seq', 17, false);


--
-- TOC entry 3388 (class 0 OID 0)
-- Dependencies: 275
-- Name: merchant_idmerch_seq; Type: SEQUENCE SET; Schema: common; Owner: postgres
--

SELECT pg_catalog.setval('common.merchant_idmerch_seq', 2, true);


--
-- TOC entry 3389 (class 0 OID 0)
-- Dependencies: 276
-- Name: service_id_service_seq; Type: SEQUENCE SET; Schema: common; Owner: postgres
--

SELECT pg_catalog.setval('common.service_id_service_seq', 2, false);


--
-- TOC entry 3390 (class 0 OID 0)
-- Dependencies: 277
-- Name: tarif_idtarif_seq; Type: SEQUENCE SET; Schema: common; Owner: postgres
--

SELECT pg_catalog.setval('common.tarif_idtarif_seq', 116, true);


--
-- TOC entry 3391 (class 0 OID 0)
-- Dependencies: 278
-- Name: tranztarif_idtranz_seq; Type: SEQUENCE SET; Schema: common; Owner: postgres
--

SELECT pg_catalog.setval('common.tranztarif_idtranz_seq', 2, true);


--
-- TOC entry 3392 (class 0 OID 0)
-- Dependencies: 307
-- Name: ekassa_id_ekassa_seq; Type: SEQUENCE SET; Schema: ekassa; Owner: postgres
--

SELECT pg_catalog.setval('ekassa.ekassa_id_ekassa_seq', 145, true);


--
-- TOC entry 3393 (class 0 OID 0)
-- Dependencies: 289
-- Name: syspay_id_paybank_seq; Type: SEQUENCE SET; Schema: mytosb; Owner: postgres
--

SELECT pg_catalog.setval('mytosb.syspay_id_paybank_seq', 598, true);


--
-- TOC entry 3394 (class 0 OID 0)
-- Dependencies: 290
-- Name: tranzserv_id_tranz_service_seq; Type: SEQUENCE SET; Schema: mytosb; Owner: postgres
--

SELECT pg_catalog.setval('mytosb.tranzserv_id_tranz_service_seq', 4, true);


--
-- TOC entry 3395 (class 0 OID 0)
-- Dependencies: 295
-- Name: payment_qrtanz_seq; Type: SEQUENCE SET; Schema: reports; Owner: postgres
--

SELECT pg_catalog.setval('reports.payment_qrtanz_seq', 2258, true);


--
-- TOC entry 3396 (class 0 OID 0)
-- Dependencies: 306
-- Name: users_idpriv_seq; Type: SEQUENCE SET; Schema: user; Owner: postgres
--

SELECT pg_catalog.setval('"user".users_idpriv_seq', 46, false);


--
-- TOC entry 3038 (class 2606 OID 30393)
-- Name: syspay doc_syspay_pkey; Type: CONSTRAINT; Schema: 2can; Owner: postgres
--

ALTER TABLE ONLY "2can".syspay
    ADD CONSTRAINT doc_syspay_pkey PRIMARY KEY (id);


--
-- TOC entry 3040 (class 2606 OID 31434)
-- Name: merchant_tap2go merchant_tap2go_pkey; Type: CONSTRAINT; Schema: 2can; Owner: postgres
--

ALTER TABLE ONLY "2can".merchant_tap2go
    ADD CONSTRAINT merchant_tap2go_pkey PRIMARY KEY (idmerch);


--
-- TOC entry 3042 (class 2606 OID 31834)
-- Name: calc_2023 calc_2023_pkey; Type: CONSTRAINT; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_2023
    ADD CONSTRAINT calc_2023_pkey PRIMARY KEY (id_calc);


--
-- TOC entry 3044 (class 2606 OID 31836)
-- Name: calc_2024 calc_2024_pkey; Type: CONSTRAINT; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_2024
    ADD CONSTRAINT calc_2024_pkey PRIMARY KEY (id_calc);


--
-- TOC entry 3046 (class 2606 OID 31838)
-- Name: calc_2025 calc_2025_pkey; Type: CONSTRAINT; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_2025
    ADD CONSTRAINT calc_2025_pkey PRIMARY KEY (id_calc);


--
-- TOC entry 3048 (class 2606 OID 31842)
-- Name: calc_2026 calc_2026_pkey; Type: CONSTRAINT; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_2026
    ADD CONSTRAINT calc_2026_pkey PRIMARY KEY (id_calc);


--
-- TOC entry 3050 (class 2606 OID 31832)
-- Name: calc_2027 calc_2027_pkey; Type: CONSTRAINT; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_2027
    ADD CONSTRAINT calc_2027_pkey PRIMARY KEY (id_calc);


--
-- TOC entry 3052 (class 2606 OID 31840)
-- Name: calc_2028 calc_2028_pkey; Type: CONSTRAINT; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer.calc_2028
    ADD CONSTRAINT calc_2028_pkey PRIMARY KEY (id_calc);


--
-- TOC entry 3054 (class 2606 OID 31869)
-- Name: order idcalc; Type: CONSTRAINT; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer."order"
    ADD CONSTRAINT idcalc UNIQUE (id_calc);


--
-- TOC entry 3056 (class 2606 OID 31877)
-- Name: order order_pkey; Type: CONSTRAINT; Schema: ataxi_transfer; Owner: postgres
--

ALTER TABLE ONLY ataxi_transfer."order"
    ADD CONSTRAINT order_pkey PRIMARY KEY (id_order);


--
-- TOC entry 2962 (class 2606 OID 29515)
-- Name: banks banks_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.banks
    ADD CONSTRAINT banks_pkey PRIMARY KEY (bik);


--
-- TOC entry 2964 (class 2606 OID 29512)
-- Name: breakesum breakesum_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.breakesum
    ADD CONSTRAINT breakesum_pkey PRIMARY KEY (idbreake);


--
-- TOC entry 2966 (class 2606 OID 29510)
-- Name: commparam commparam_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.commparam
    ADD CONSTRAINT commparam_pkey PRIMARY KEY (idcommparam);


--
-- TOC entry 3006 (class 2606 OID 29524)
-- Name: commun communication_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.commun
    ADD CONSTRAINT communication_pkey PRIMARY KEY (idcommun);


--
-- TOC entry 2968 (class 2606 OID 29526)
-- Name: department department_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.department
    ADD CONSTRAINT department_pkey PRIMARY KEY (id);


--
-- TOC entry 2970 (class 2606 OID 29528)
-- Name: firmservice firmservice_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.firmservice
    ADD CONSTRAINT firmservice_pkey PRIMARY KEY (idfirm);


--
-- TOC entry 2972 (class 2606 OID 29530)
-- Name: merchant merchant_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.merchant
    ADD CONSTRAINT merchant_pkey PRIMARY KEY (idmerch);


--
-- TOC entry 2974 (class 2606 OID 29532)
-- Name: organisations organisations_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.organisations
    ADD CONSTRAINT organisations_pkey PRIMARY KEY ("Inn_org");


--
-- TOC entry 2976 (class 2606 OID 31423)
-- Name: service service_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.service
    ADD CONSTRAINT service_pkey PRIMARY KEY (id_service);


--
-- TOC entry 2978 (class 2606 OID 29536)
-- Name: tarif tarif_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.tarif
    ADD CONSTRAINT tarif_pkey PRIMARY KEY (idtarif);


--
-- TOC entry 2980 (class 2606 OID 29539)
-- Name: tranztarif tranztarif_pkey; Type: CONSTRAINT; Schema: common; Owner: postgres
--

ALTER TABLE ONLY common.tranztarif
    ADD CONSTRAINT tranztarif_pkey PRIMARY KEY ("Firm", "Tarif", "Syspay", "Breakesum", "Enable");


--
-- TOC entry 3008 (class 2606 OID 29655)
-- Name: ekassa_2023 ekassa_2023_pkey; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2023
    ADD CONSTRAINT ekassa_2023_pkey PRIMARY KEY (id_ekassa);


--
-- TOC entry 3012 (class 2606 OID 29659)
-- Name: ekassa_2024 ekassa_2024_pkey; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2024
    ADD CONSTRAINT ekassa_2024_pkey PRIMARY KEY (id_ekassa);


--
-- TOC entry 3016 (class 2606 OID 29663)
-- Name: ekassa_2025 ekassa_2025_pkey; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2025
    ADD CONSTRAINT ekassa_2025_pkey PRIMARY KEY (id_ekassa);


--
-- TOC entry 3020 (class 2606 OID 29667)
-- Name: ekassa_2026 ekassa_2026_pkey; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2026
    ADD CONSTRAINT ekassa_2026_pkey PRIMARY KEY (id_ekassa);


--
-- TOC entry 3024 (class 2606 OID 29671)
-- Name: ekassa_2027 ekassa_2027_pkey; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2027
    ADD CONSTRAINT ekassa_2027_pkey PRIMARY KEY (id_ekassa);


--
-- TOC entry 3028 (class 2606 OID 29675)
-- Name: ekassa_2028 ekassa_2028_pkey; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2028
    ADD CONSTRAINT ekassa_2028_pkey PRIMARY KEY (id_ekassa);


--
-- TOC entry 3032 (class 2606 OID 29679)
-- Name: ekassa_2029 ekassa_2029_pkey; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2029
    ADD CONSTRAINT ekassa_2029_pkey PRIMARY KEY (id_ekassa);


--
-- TOC entry 3010 (class 2606 OID 29653)
-- Name: ekassa_2023 qtranz_pay2023; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2023
    ADD CONSTRAINT qtranz_pay2023 UNIQUE (qtranz_payment);


--
-- TOC entry 3014 (class 2606 OID 29657)
-- Name: ekassa_2024 qtranz_pay2024; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2024
    ADD CONSTRAINT qtranz_pay2024 UNIQUE (qtranz_payment);


--
-- TOC entry 3018 (class 2606 OID 29661)
-- Name: ekassa_2025 qtranz_pay2025; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2025
    ADD CONSTRAINT qtranz_pay2025 UNIQUE (qtranz_payment);


--
-- TOC entry 3022 (class 2606 OID 29665)
-- Name: ekassa_2026 qtranz_pay2026; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2026
    ADD CONSTRAINT qtranz_pay2026 UNIQUE (qtranz_payment);


--
-- TOC entry 3026 (class 2606 OID 29669)
-- Name: ekassa_2027 qtranz_pay2027; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2027
    ADD CONSTRAINT qtranz_pay2027 UNIQUE (qtranz_payment);


--
-- TOC entry 3030 (class 2606 OID 29673)
-- Name: ekassa_2028 qtranz_pay2028; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2028
    ADD CONSTRAINT qtranz_pay2028 UNIQUE (qtranz_payment);


--
-- TOC entry 3034 (class 2606 OID 29677)
-- Name: ekassa_2029 qtranz_pay2029; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa_2029
    ADD CONSTRAINT qtranz_pay2029 UNIQUE (qtranz_payment);


--
-- TOC entry 3036 (class 2606 OID 29692)
-- Name: ekassa spr_ekassa_pkey; Type: CONSTRAINT; Schema: ekassa; Owner: postgres
--

ALTER TABLE ONLY ekassa.ekassa
    ADD CONSTRAINT spr_ekassa_pkey PRIMARY KEY (id_kass);


--
-- TOC entry 2984 (class 2606 OID 29399)
-- Name: syspay doc_syspay_pkey; Type: CONSTRAINT; Schema: mytosb; Owner: postgres
--

ALTER TABLE ONLY mytosb.syspay
    ADD CONSTRAINT doc_syspay_pkey PRIMARY KEY (id_paybank);


--
-- TOC entry 2986 (class 2606 OID 29397)
-- Name: syspay idpay; Type: CONSTRAINT; Schema: mytosb; Owner: postgres
--

ALTER TABLE ONLY mytosb.syspay
    ADD CONSTRAINT idpay UNIQUE (idpay);


--
-- TOC entry 3397 (class 0 OID 0)
-- Dependencies: 2986
-- Name: CONSTRAINT idpay ON syspay; Type: COMMENT; Schema: mytosb; Owner: postgres
--

COMMENT ON CONSTRAINT idpay ON mytosb.syspay IS 'Уникальные значения';


--
-- TOC entry 2982 (class 2606 OID 29394)
-- Name: contracts tranz_service_pkey; Type: CONSTRAINT; Schema: mytosb; Owner: postgres
--

ALTER TABLE ONLY mytosb.contracts
    ADD CONSTRAINT tranz_service_pkey PRIMARY KEY (id_tranzservice);


--
-- TOC entry 2988 (class 2606 OID 29401)
-- Name: users users_pkey; Type: CONSTRAINT; Schema: mytosb; Owner: postgres
--

ALTER TABLE ONLY mytosb.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id_users);


--
-- TOC entry 2990 (class 2606 OID 29485)
-- Name: payment_2023 payment_2023_pkey; Type: CONSTRAINT; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment_2023
    ADD CONSTRAINT payment_2023_pkey PRIMARY KEY (idpaymerch);


--
-- TOC entry 2992 (class 2606 OID 29487)
-- Name: payment_2024 payment_2024_pkey; Type: CONSTRAINT; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment_2024
    ADD CONSTRAINT payment_2024_pkey PRIMARY KEY (idpaymerch);


--
-- TOC entry 2994 (class 2606 OID 29489)
-- Name: payment_2025 payment_2025_pkey; Type: CONSTRAINT; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment_2025
    ADD CONSTRAINT payment_2025_pkey PRIMARY KEY (idpaymerch);


--
-- TOC entry 2996 (class 2606 OID 29491)
-- Name: payment_2026 payment_2026_pkey; Type: CONSTRAINT; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment_2026
    ADD CONSTRAINT payment_2026_pkey PRIMARY KEY (idpaymerch);


--
-- TOC entry 2998 (class 2606 OID 29493)
-- Name: payment_2027 payment_2027_pkey; Type: CONSTRAINT; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment_2027
    ADD CONSTRAINT payment_2027_pkey PRIMARY KEY (idpaymerch);


--
-- TOC entry 3000 (class 2606 OID 29495)
-- Name: payment_2028 payment_2028_pkey; Type: CONSTRAINT; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment_2028
    ADD CONSTRAINT payment_2028_pkey PRIMARY KEY (idpaymerch);


--
-- TOC entry 3002 (class 2606 OID 29497)
-- Name: payment_2029 payment_2029_pkey; Type: CONSTRAINT; Schema: reports; Owner: postgres
--

ALTER TABLE ONLY reports.payment_2029
    ADD CONSTRAINT payment_2029_pkey PRIMARY KEY (idpaymerch);


--
-- TOC entry 3004 (class 2606 OID 29506)
-- Name: users spr_privilege_pkey; Type: CONSTRAINT; Schema: user; Owner: postgres
--

ALTER TABLE ONLY "user".users
    ADD CONSTRAINT spr_privilege_pkey PRIMARY KEY (idpriv);


--
-- TOC entry 3057 (class 1259 OID 31903)
-- Name: tariffs_list_idx_id_price; Type: INDEX; Schema: ataxi_transfer; Owner: vdskkp
--

CREATE INDEX tariffs_list_idx_id_price ON ataxi_transfer.mv_tariffs USING btree (id_price);


--
-- TOC entry 3058 (class 2620 OID 31917)
-- Name: syspay tr_order_status; Type: TRIGGER; Schema: mytosb; Owner: postgres
--

CREATE TRIGGER tr_order_status BEFORE UPDATE OF json_callback ON mytosb.syspay FOR EACH ROW EXECUTE FUNCTION ataxi_transfer.f_order_status();


--
-- TOC entry 3059 (class 2620 OID 30211)
-- Name: syspay tr_payment; Type: TRIGGER; Schema: mytosb; Owner: postgres
--

CREATE TRIGGER tr_payment AFTER UPDATE OF json_callback ON mytosb.syspay FOR EACH ROW EXECUTE FUNCTION mytosb.f_tr_payment();


--
-- TOC entry 3269 (class 0 OID 31898)
-- Dependencies: 358 3272
-- Name: mv_tariffs; Type: MATERIALIZED VIEW DATA; Schema: ataxi_transfer; Owner: vdskkp
--

REFRESH MATERIALIZED VIEW ataxi_transfer.mv_tariffs;


-- Completed on 2023-09-04 22:44:41

--
-- PostgreSQL database dump complete
--

