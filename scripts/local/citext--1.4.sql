/* contrib/citext/citext--1.4.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION


--
--  PostgreSQL code for CITEXT.
--
-- Most I/O functions, and a few others, piggyback on the "text" type
-- functions via the implicit cast to text.
--

--
-- Shell type to keep things a bit quieter.
--

CREATE TYPE citext;

--
--  Input and output functions.
--
CREATE FUNCTION citextin(cstring)
RETURNS citext
AS 'textin'
LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citextout(citext)
RETURNS cstring
AS 'textout'
LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citextrecv(internal)
RETURNS citext
AS 'textrecv'
LANGUAGE internal STABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citextsend(citext)
RETURNS bytea
AS 'textsend'
LANGUAGE internal STABLE STRICT PARALLEL SAFE;

--
--  The type itself.
--

CREATE TYPE citext (
    INPUT          = citextin,
    OUTPUT         = citextout,
    RECEIVE        = citextrecv,
    SEND           = citextsend,
    INTERNALLENGTH = VARIABLE,
    STORAGE        = extended,
    -- make it a non-preferred member of string type category
    CATEGORY       = 'S',
    PREFERRED      = false,
    COLLATABLE     = true
);

--
-- Type casting functions for those situations where the I/O casts don't
-- automatically kick in.
--

CREATE FUNCTION citext(bpchar)
RETURNS citext
AS 'rtrim1'
LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citext(boolean)
RETURNS citext
AS 'booltext'
LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citext(inet)
RETURNS citext
AS 'network_show'
LANGUAGE internal IMMUTABLE STRICT PARALLEL SAFE;

--
--  Implicit and assignment type casts.
--

CREATE CAST (citext AS text)    WITHOUT FUNCTION AS IMPLICIT;
CREATE CAST (citext AS varchar) WITHOUT FUNCTION AS IMPLICIT;
CREATE CAST (citext AS bpchar)  WITHOUT FUNCTION AS ASSIGNMENT;
CREATE CAST (text AS citext)    WITHOUT FUNCTION AS ASSIGNMENT;
CREATE CAST (varchar AS citext) WITHOUT FUNCTION AS ASSIGNMENT;
CREATE CAST (bpchar AS citext)  WITH FUNCTION citext(bpchar)  AS ASSIGNMENT;
CREATE CAST (boolean AS citext) WITH FUNCTION citext(boolean) AS ASSIGNMENT;
CREATE CAST (inet AS citext)    WITH FUNCTION citext(inet)    AS ASSIGNMENT;

--
-- Operator Functions.
--

CREATE FUNCTION citext_eq( citext, citext )
RETURNS bool
AS $$ SELECT lower($1::pg_catalog.text) = lower($2::pg_catalog.text) $$
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citext_ne( citext, citext )
RETURNS bool
AS $$ SELECT lower($1::pg_catalog.text) <> lower($2::pg_catalog.text) $$
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citext_lt( citext, citext )
RETURNS bool
AS $$ SELECT lower($1::pg_catalog.text) < lower($2::pg_catalog.text) $$
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citext_le( citext, citext )
RETURNS bool
AS $$ SELECT lower($1::pg_catalog.text) <= lower($2::pg_catalog.text) $$
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citext_gt( citext, citext )
RETURNS bool
AS $$ SELECT lower($1::pg_catalog.text) > lower($2::pg_catalog.text) $$
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citext_ge( citext, citext )
RETURNS bool
AS $$ SELECT lower($1::pg_catalog.text) >= lower($2::pg_catalog.text) $$
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

--
-- Operators.
--

CREATE OPERATOR = (
    LEFTARG    = CITEXT,
    RIGHTARG   = CITEXT,
    COMMUTATOR = =,
    NEGATOR    = <>,
    PROCEDURE  = citext_eq,
    RESTRICT   = eqsel,
    JOIN       = eqjoinsel,
    HASHES,
    MERGES
);

CREATE OPERATOR <> (
    LEFTARG    = CITEXT,
    RIGHTARG   = CITEXT,
    NEGATOR    = =,
    COMMUTATOR = <>,
    PROCEDURE  = citext_ne,
    RESTRICT   = neqsel,
    JOIN       = neqjoinsel
);

CREATE OPERATOR < (
    LEFTARG    = CITEXT,
    RIGHTARG   = CITEXT,
    NEGATOR    = >=,
    COMMUTATOR = >,
    PROCEDURE  = citext_lt,
    RESTRICT   = scalarltsel,
    JOIN       = scalarltjoinsel
);

CREATE OPERATOR <= (
    LEFTARG    = CITEXT,
    RIGHTARG   = CITEXT,
    NEGATOR    = >,
    COMMUTATOR = >=,
    PROCEDURE  = citext_le,
    RESTRICT   = scalarltsel,
    JOIN       = scalarltjoinsel
);

CREATE OPERATOR >= (
    LEFTARG    = CITEXT,
    RIGHTARG   = CITEXT,
    NEGATOR    = <,
    COMMUTATOR = <=,
    PROCEDURE  = citext_ge,
    RESTRICT   = scalargtsel,
    JOIN       = scalargtjoinsel
);

CREATE OPERATOR > (
    LEFTARG    = CITEXT,
    RIGHTARG   = CITEXT,
    NEGATOR    = <=,
    COMMUTATOR = <,
    PROCEDURE  = citext_gt,
    RESTRICT   = scalargtsel,
    JOIN       = scalargtjoinsel
);

--
-- Support functions for indexing.
--

CREATE FUNCTION citext_cmp( citext, citext )
RETURNS int4
AS $$ SELECT pg_catalog.bttextcmp(lower($1::pg_catalog.text), lower($2::pg_catalog.text)) $$
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

CREATE FUNCTION citext_hash(citext)
RETURNS int4
AS $$ SELECT pg_catalog.hashtext(lower($1::pg_catalog.text)) $$
LANGUAGE SQL IMMUTABLE STRICT PARALLEL SAFE;

--
-- The btree indexing operator class.
--

CREATE OPERATOR CLASS citext_ops
DEFAULT FOR TYPE CITEXT USING btree AS
    OPERATOR    1   <  (citext, citext),
    OPERATOR    2   <= (citext, citext),
    OPERATOR    3   =  (citext, citext),
    OPERATOR    4   >= (citext, citext),
    OPERATOR    5   >  (citext, citext),
    FUNCTION    1   citext_cmp(citext, citext);

--
-- The hash indexing operator class.
--

CREATE OPERATOR CLASS citext_ops
DEFAULT FOR TYPE citext USING hash AS
    OPERATOR    1   =  (citext, citext),
    FUNCTION    1   citext_hash(citext);

--
-- Aggregates.
--
