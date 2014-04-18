-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('text_refs-schema.sql', '$Id');

--	Wicci Project Virtual Text Schema

-- ** Copyright

--	Copyright (c) 2005, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** Virtual Text

-- See text_refs-notes.text for more information.

-- A piece of Virtual Text is either a Leaf or a Tree or a Subrange.
-- All Leaf objects can cheaply compute their length
-- Molecules are pieces of Virtual Context-dependent Text

-- ** type text_refs

SELECT create_ref_type('text_refs');

-- * key table and abstract base classes

CREATE TABLE IF NOT EXISTS text_keys (
	key text_refs PRIMARY KEY
);

SELECT create_handles_for('text_keys');
SELECT create_key_trigger_functions_for('text_keys');

-- **  TABLE abstract_text_rows(ref text_refs) -- ABSTRACT BASE
CREATE TABLE IF NOT EXISTS abstract_text_rows (
	ref text_refs
);
COMMENT ON TABLE abstract_text_rows IS
'unique references for any kind of data,
which can be cheaply rendered as text;
this is an abstract base class';

SELECT declare_abstract('abstract_text_rows');
SELECT declare_ref_type_class('text_refs', 'abstract_text_rows');

-- * id management

CREATE OR REPLACE
FUNCTION unchecked_text_from_class_id(regclass, ref_ids)
RETURNS text_refs AS $$
	SELECT unchecked_ref('text_refs', $1, $2)::text_refs
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION text_nil() RETURNS text_refs AS $$
	SELECT unchecked_text_from_class_id(
		'abstract_text_rows',  0
	)
$$ LANGUAGE SQL IMMUTABLE;

INSERT INTO text_keys VALUES (text_nil());

DROP SEQUENCE IF EXISTS text_id_seq CASCADE;

CREATE SEQUENCE text_id_seq
	OWNED BY abstract_text_rows.ref
	MINVALUE 1 MAXVALUE :RefIdMax CYCLE;

CREATE OR REPLACE
FUNCTION next_text(regclass) RETURNS text_refs AS $$
	SELECT unchecked_text_from_class_id(
		$1, nextval('text_id_seq')::ref_ids
	)
$$ LANGUAGE SQL;

-- * Concrete Leaf Class

-- ** TABLE text_string_rows(ref text_refs,  string_ text)

CREATE TABLE IF NOT EXISTS text_string_rows (
	PRIMARY KEY (ref),
	string_ TEXT NOT NULL UNIQUE
) INHERITS(abstract_text_rows);
COMMENT ON TABLE text_string_rows IS '
	unique typed text strings with unique refs;
	their refs may not be shared with other processes;
	they may be aggressively garbage collected
';

ALTER TABLE text_string_rows ALTER COLUMN ref
	SET DEFAULT next_text( 'text_string_rows' );

SELECT create_key_triggers_for('text_string_rows', 'text_keys');
SELECT declare_ref_class('text_string_rows');

-- *  Text_Refs Tree Classes

-- consider changing branches to be refs[] with
-- the constraint of supporting ref_text!!!

CREATE OR REPLACE
FUNCTION text_branches_check(refs[]) RETURNS boolean AS $$
	SELECT CASE WHEN x IS NULL THEN false
	ELSE refs_op_tag_to_method(
		'ref_text_op(refs)', ref_tag(x)
	) IS NOT NULL
	END
	FROM unnest($1) x
$$ LANGUAGE SQL;

-- ** TABLE abstract_text_tree_rows(ref)
CREATE TABLE IF NOT EXISTS abstract_text_tree_rows (
	length_ bigint,
--  branches text_refs[] NOT NULL CHECK( array_has_no_nulls(branches) )
	branches refs[] NOT NULL CHECK( text_branches_check(branches) )
) INHERITS(abstract_text_rows);

SELECT declare_abstract('abstract_text_tree_rows');

-- * text_join_tree_rows

-- ** TABLE text_join_tree_rows(ref, length_, branches _text, join_ text_refs)
CREATE TABLE IF NOT EXISTS text_join_tree_rows (
	PRIMARY KEY (ref),
	join_ text NOT NULL,
	UNIQUE(branches, join_)
) INHERITS(abstract_text_tree_rows);
COMMENT ON TABLE text_join_tree_rows IS
'represents a text value by an array of text values along with a
string to join them';

ALTER TABLE text_join_tree_rows ALTER COLUMN ref
	SET DEFAULT next_text( 'text_join_tree_rows' );

SELECT create_key_triggers_for('text_join_tree_rows', 'text_keys');
SELECT declare_ref_class('text_join_tree_rows');

-- * text_format_tree_rows

CREATE TABLE IF NOT EXISTS text_tree_formats (
	id serial PRIMARY KEY,
	formats text[] UNIQUE NOT NULL
	CHECK( array_has_no_nulls(formats) )
);

SELECT declare_monotonic('text_tree_formats');
SELECT create_handles_for('text_tree_formats');

CREATE OR REPLACE FUNCTION text_format_dim_ok(
	format_id integer, num_branches integer
) RETURNS boolean AS $$
	SELECT array_length(formats) - $2 <= 1
	FROM text_tree_formats WHERE id=$1
$$ LANGUAGE SQL IMMUTABLE;
COMMENT ON FUNCTION text_format_dim_ok(integer, integer) IS
'Are there enough and not too many format elements to format the
branches?';

-- ** TABLE text_format_tree_rows(ref, length_, branches, format_id)
CREATE TABLE IF NOT EXISTS text_format_tree_rows (
	PRIMARY KEY (ref),
	format_id integer NOT NULL REFERENCES text_tree_formats,
	CONSTRAINT text_format_tree_rows_correspondence
		 CHECK( text_format_dim_ok(format_id, array_length(branches)) ),
	UNIQUE(branches, format_id)
) INHERITS(abstract_text_tree_rows);
COMMENT ON TABLE text_format_tree_rows IS
'branches  interleaved with the format array';

ALTER TABLE text_format_tree_rows ALTER COLUMN ref
	SET DEFAULT next_text( 'text_format_tree_rows' );

SELECT create_key_triggers_for('text_format_tree_rows', 'text_keys');
SELECT declare_ref_class('text_format_tree_rows');

-- * Operations

-- oftd !!!
CREATE OR REPLACE FUNCTION oftd_ref_env_crefs_length_op(
	regprocedure, refs[], refs[], refs, refs, env_refs, crefs
) RETURNS :WordIntsPG
AS 'spx.so', 'oftd_ref_env_crefs_etc_scalar_op'
LANGUAGE c STABLE;

-- oftd !!!
CREATE OR REPLACE FUNCTION oftd_ref_env_crefs_chiln_length_op(
	regprocedure, refs[], refs[], refs, refs, env_refs, crefs, refs[]
) RETURNS :WordIntsPG
AS 'spx.so', 'oftd_ref_env_crefs_etc_scalar_op'
LANGUAGE c STABLE;

CREATE OR REPLACE
FUNCTION env_length_op(refs, env_refs) RETURNS :WordIntsPG
AS 'spx.so', 'call_scalar_method'  LANGUAGE c STABLE;

SELECT declare_op_fallback(
	'env_length_op(refs, env_refs)',
	'ref_length_op(refs)'
);

CREATE OR REPLACE
FUNCTION ref_env_crefs_length_op(refs, env_refs, crefs)
RETURNS :WordIntsPG
AS 'spx.so', 'ref_env_crefs_etc_scalar_op'
LANGUAGE c STABLE;

SELECT declare_op_fallback(
	'ref_env_crefs_length_op(refs, env_refs, crefs)',
	'env_length_op(refs, env_refs)'
);

CREATE OR REPLACE FUNCTION ref_env_crefs_chiln_length_op(
	refs, env_refs, crefs, refs[]
) RETURNS :WordIntsPG
AS 'spx.so', 'ref_env_crefs_etc_scalar_op'
LANGUAGE c STABLE;

SELECT declare_op_fallback(
	'ref_env_crefs_chiln_length_op(refs, env_refs, crefs, refs[])',
	'ref_env_crefs_length_op(refs, env_refs, crefs)'
);
