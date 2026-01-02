--
-- PostgreSQL database dump
--

\restrict pJ8x47epvyMxH0IJLfpkCt5aMXlmHHMPgOknNeKeje7GYiBN4dMuUNRS86lQd94

-- Dumped from database version 18.1
-- Dumped by pg_dump version 18.1

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: timescaledb; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS timescaledb WITH SCHEMA public;


--
-- Name: EXTENSION timescaledb; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION timescaledb IS 'Enables scalable inserts and complex queries for time-series data (Community Edition)';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: log_entries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.log_entries (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    project_id uuid NOT NULL,
    "timestamp" timestamp(6) without time zone NOT NULL,
    level character varying NOT NULL,
    message text,
    commit character varying,
    branch character varying,
    environment character varying,
    service character varying,
    host character varying,
    request_id character varying,
    session_id character varying,
    data jsonb DEFAULT '{}'::jsonb,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: projects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.projects (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    slug character varying NOT NULL,
    ingest_key character varying NOT NULL,
    api_key character varying NOT NULL,
    logs_count bigint DEFAULT 0,
    bytes_total bigint DEFAULT 0,
    retention_days integer DEFAULT 30,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    archive_enabled boolean DEFAULT false,
    last_archived_at timestamp(6) without time zone
);


--
-- Name: saved_searches; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.saved_searches (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying NOT NULL,
    query character varying NOT NULL,
    project_id uuid NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: log_entries log_entries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.log_entries
    ADD CONSTRAINT log_entries_pkey PRIMARY KEY (id, "timestamp");


--
-- Name: projects projects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.projects
    ADD CONSTRAINT projects_pkey PRIMARY KEY (id);


--
-- Name: saved_searches saved_searches_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT saved_searches_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: index_log_entries_on_data; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_data ON public.log_entries USING gin (data jsonb_path_ops);


--
-- Name: index_log_entries_on_message; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_message ON public.log_entries USING gin (message public.gin_trgm_ops);


--
-- Name: index_log_entries_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_project_id ON public.log_entries USING btree (project_id);


--
-- Name: index_log_entries_on_project_id_and_commit; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_project_id_and_commit ON public.log_entries USING btree (project_id, commit);


--
-- Name: index_log_entries_on_project_id_and_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_project_id_and_level ON public.log_entries USING btree (project_id, level);


--
-- Name: index_log_entries_on_project_id_and_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_project_id_and_session_id ON public.log_entries USING btree (project_id, session_id);


--
-- Name: index_log_entries_on_project_id_and_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_project_id_and_timestamp ON public.log_entries USING btree (project_id, "timestamp");


--
-- Name: index_log_entries_on_request_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_request_id ON public.log_entries USING btree (request_id);


--
-- Name: index_log_entries_on_session_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_session_id ON public.log_entries USING btree (session_id);


--
-- Name: index_log_entries_on_timestamp; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_log_entries_on_timestamp ON public.log_entries USING btree ("timestamp");


--
-- Name: index_projects_on_api_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_api_key ON public.projects USING btree (api_key);


--
-- Name: index_projects_on_ingest_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_ingest_key ON public.projects USING btree (ingest_key);


--
-- Name: index_projects_on_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_name ON public.projects USING btree (name);


--
-- Name: index_projects_on_slug; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_projects_on_slug ON public.projects USING btree (slug);


--
-- Name: index_saved_searches_on_project_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_saved_searches_on_project_id ON public.saved_searches USING btree (project_id);


--
-- Name: index_saved_searches_on_project_id_and_name; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_saved_searches_on_project_id_and_name ON public.saved_searches USING btree (project_id, name);


--
-- Name: saved_searches fk_rails_72f9101377; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.saved_searches
    ADD CONSTRAINT fk_rails_72f9101377 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Name: log_entries fk_rails_c1560bb064; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.log_entries
    ADD CONSTRAINT fk_rails_c1560bb064 FOREIGN KEY (project_id) REFERENCES public.projects(id);


--
-- Data for Name: schema_migrations; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.schema_migrations (version) VALUES
('20251221073338'),
('20251221073339'),
('20251221092322'),
('20251221102000'),
('20251223200000'),
('20251227233250');


--
-- PostgreSQL database dump complete
--

\unrestrict pJ8x47epvyMxH0IJLfpkCt5aMXlmHHMPgOknNeKeje7GYiBN4dMuUNRS86lQd94

