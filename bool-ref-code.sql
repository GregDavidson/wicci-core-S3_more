-- * Header  -*-Mode: sql;-*-
\ir settings.sql
SELECT set_file('more-bool-code.sql', '$Id');

--	Wicci Project Virtual Text Schema
--	bool_refs: typed booleans

-- ** Copyright

--	Copyright (c) 2005-2012, J. Greg Davidson.
--	You may use this file under the terms of the
--	GNU AFFERO GENERAL PUBLIC LICENSE 3.0
--	as specified in the file LICENSE.md included with this distribution.
--	All other use requires my permission in writing.

-- ** initializers

CREATE OR REPLACE
FUNCTION declare_bool_env_literal(env_refs, boolean, name_refs)
RETURNS integer AS $$
	SELECT env_key_set($1, bool_ref_key($2), $3);
	SELECT 1
$$ LANGUAGE SQL;
	
CREATE OR REPLACE FUNCTION declare_bool_env_literals(
	env_refs, name_refs, name_refs
) RETURNS integer AS $$
	SELECT
		declare_bool_env_literal($1, false, $2)
 + declare_bool_env_literal($1, true, $3)
$$ LANGUAGE SQL;

SELECT declare_name('false',  'true');
SELECT declare_bool_env_literals(
	system_base_env(), 'false', 'true'
);

CREATE OR REPLACE
FUNCTION declare_bool_ref_literal(env_refs, name_refs)
RETURNS integer AS $$
	DECLARE
		maybe RECORD;
		kilroy_was_here boolean := false;
		this regprocedure := 'declare_bool_ref_literal(env_refs, name_refs)';
	BEGIN
		LOOP
			SELECT * INTO maybe FROM bool_literals WHERE name = $2;
			IF FOUND THEN
				IF maybe.env != $1 THEN
					RAISE EXCEPTION '%: % % != % %',
						this, $1, $2, maybe.env, maybe.name;
				END IF;
				RETURN 1;
			END IF;
			IF kilroy_was_here THEN
				RAISE EXCEPTION '% looping on % %', this, $1, $2;
			END IF;
			kilroy_was_here := true;
			BEGIN
				INSERT INTO bool_literals(env, name) VALUES ($1, $2);
			EXCEPTION
				WHEN unique_violation THEN	-- another thread?
					RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
			END;
		END LOOP;
	END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION declare_bool_ref_literals(env_refs, name_refs, name_refs)
RETURNS integer AS $$
  SELECT
		declare_bool_ref_literal($1, $2) + declare_bool_ref_literal($1, $3)
$$ LANGUAGE SQL;

SELECT declare_bool_ref_literals(
	system_base_env(), 'false', 'true'
);

CREATE OR REPLACE
FUNCTION declare_bool_ref_(env_refs, boolean)
RETURNS integer AS $$
DECLARE
	kilroy_was_here boolean := false;
	this regprocedure := 'declare_bool_ref_(env_refs, boolean)';
BEGIN
	LOOP
		PERFORM ref FROM bool_rows
		WHERE env = $1 AND value_ = $2;
		IF FOUND THEN RETURN 1; END IF;
		IF kilroy_was_here THEN
			RAISE EXCEPTION '% looping with % %', this, $1, $2;
		END IF;
		BEGIN
			INSERT INTO bool_rows(env, value_) VALUES ($1, $2);
		EXCEPTION
			WHEN unique_violation THEN	-- another thread?
				RAISE NOTICE '% % % raised %!', this, $1, $2, 'unique_violation';
		END;
	END LOOP;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE
FUNCTION declare_bool_refs(env_refs) RETURNS integer AS $$
  SELECT declare_bool_ref_($1, false) + declare_bool_ref_($1, true)
$$ LANGUAGE SQL;
COMMENT ON FUNCTION declare_bool_refs(env_refs) IS
'ensure that there exists a bool_refs pair, one false and one true,
both with the given environment';

-- ** Extractors

CREATE OR REPLACE
FUNCTION try_bool_env_(text) RETURNS env_refs AS $$
	SELECT env FROM bool_literals
	WHERE name = try_name($1)
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_bool_env(text) RETURNS env_refs AS $$
	SELECT CASE
		WHEN env = bool_ref_env() THEN env_nil()
		ELSE env										-- which might be NULL!
	END FROM try_bool_env_($1) env
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION is_bool_ref_text( text ) RETURNS boolean AS $$
	SELECT try_bool_env($1) IS NOT NULL
$$ LANGUAGE SQL IMMUTABLE;

-- ** Constructors

CREATE OR REPLACE
FUNCTION try_bool_ref( boolean, env_refs )
RETURNS bool_refs AS $$
	SELECT ref FROM bool_rows WHERE value_ = $1 AND env = $2
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION bool_ref( boolean, env_refs )
RETURNS bool_refs AS $$
	SELECT non_null(try_bool_ref($1, $2), 'bool_ref(bool, env_refs)')
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE
FUNCTION bool_ref( boolean )
RETURNS bool_refs AS $$
	SELECT bool_ref($1, env_nil())
$$ LANGUAGE SQL IMMUTABLE;

CREATE OR REPLACE
FUNCTION try_bool_ref( text, env_refs )
RETURNS bool_refs AS $$
	SELECT CASE _name
		WHEN bool_ref_name(false, $2) THEN bool_ref(false, $2)
		WHEN bool_ref_name(true, $2) THEN bool_ref(true, $2)
	END
	FROM try_name($1) _name
$$ LANGUAGE SQL STRICT;

CREATE OR REPLACE
FUNCTION bool_ref( text, env_refs )
RETURNS bool_refs AS $$
	SELECT non_null(try_bool_ref($1, $2), 'bool_ref(text, env_refs)')
$$ LANGUAGE SQL;

CREATE OR REPLACE
FUNCTION try_bool_ref(text) RETURNS bool_refs AS $$
	SELECT try_bool_ref($1, try_bool_env($1))
$$ LANGUAGE SQL STRICT IMMUTABLE;

CREATE OR REPLACE
FUNCTION bool_ref_(text) RETURNS bool_refs AS $$
	SELECT non_null(try_bool_ref($1), 'bool_ref_(text)')
$$ LANGUAGE SQL IMMUTABLE;

DROP CAST IF EXISTS (boolean AS bool_refs) CASCADE;

CREATE CAST (boolean AS bool_refs)
WITH FUNCTION bool_ref(boolean);

-- * type bool_refs class bool_rows to_text method

SELECT spx_debug_on();
SELECT refs_debug_on();

-- +++ bool_ref_text(bool_refs, env_refs) -> TEXT
CREATE OR REPLACE
FUNCTION bool_ref_text( bool_refs, env_refs=bool_ref_env() )
RETURNS TEXT AS $$
	SELECT env_best_text(
		$2, $1, bool_ref_key(value_), env, bool_ref_env()
	) FROM bool_rows WHERE ref = $1;
$$ LANGUAGE SQL;

-- * register the methods

-- SELECT type_class_io(
-- 	'bool_refs', 'bool_rows',
-- 	'get_bool_ref_(boolean)', 'bool_ref_text(bool_refs, env_refs)'
-- );

SELECT type_class_op_method(
	'bool_refs', 'bool_rows',
	'ref_env_text_op(refs, env_refs)', 'bool_ref_text(bool_refs, env_refs)'
);
