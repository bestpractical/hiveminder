--
-- PostgreSQL database dump
--

SET client_encoding = 'UTF8';
SET standard_conforming_strings = off;
SET check_function_bodies = false;
SET client_min_messages = warning;
SET escape_string_warning = off;

SET search_path = public, pg_catalog;

SET default_tablespace = '';

SET default_with_oids = false;

--
-- Name: _jifty_sessions; Type: TABLE; Schema: public; Owner: postgres; Tablespace: 
--

CREATE TABLE _jifty_sessions (
    id integer NOT NULL,
    session_id character varying(32),
    data_key text,
    value bytea,
    created timestamp with time zone,
    updated timestamp with time zone,
    key_type character varying(32)
);


ALTER TABLE public._jifty_sessions OWNER TO postgres;

--
-- Name: _jifty_sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE _jifty_sessions_id_seq
    INCREMENT BY 1
    NO MAXVALUE
    NO MINVALUE
    CACHE 1;


ALTER TABLE public._jifty_sessions_id_seq OWNER TO postgres;

--
-- Name: _jifty_sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE _jifty_sessions_id_seq OWNED BY _jifty_sessions.id;


--
-- Name: id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE _jifty_sessions ALTER COLUMN id SET DEFAULT nextval('_jifty_sessions_id_seq'::regclass);


--
-- Name: _jifty_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres; Tablespace: 
--

ALTER TABLE ONLY _jifty_sessions
    ADD CONSTRAINT _jifty_sessions_pkey PRIMARY KEY (id);


--
-- Name: _jifty_sessions1; Type: INDEX; Schema: public; Owner: postgres; Tablespace: 
--

CREATE INDEX _jifty_sessions1 ON _jifty_sessions USING btree (session_id);


--
-- PostgreSQL database dump complete
--

