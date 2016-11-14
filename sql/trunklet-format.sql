SELECT trunklet.template_language__add(
  language_name := 'format'
  , parameter_type := 'jsonb'
  , template_type := 'text'
  , process_function_options := 'LANGUAGE plpgsql'
  , process_function_body := $process_body$
DECLARE
  c_param CONSTANT jsonb := parameters::jsonb;
  v_return text;
BEGIN
  -- DUPLICATED IN BOTH FUNCTIONS
  IF jsonb_typeof(c_param) <> 'object' THEN
    RAISE EXCEPTION 'parameters must be a JSON object, not %', jsonb_typeof(c_param)
      USING DETAIL = format('parameters = %L', c_param)
    ;
  END IF;

  -- Sanity-check parameters
  -- DUPLICATED IN BOTH FUNCTIONS
  DECLARE
    parameter_name text;
    value text;
    v_type text;
  BEGIN
    FOR parameter_name, value IN SELECT * FROM jsonb_each( c_param )
    LOOP
      IF parameter_name ~ '%' THEN
        RAISE EXCEPTION
          USING DETAIL = 'parameter_name ' || parameter_name
            -- MESSAGE instead of trying to escape %
            , MESSAGE = 'parameter names may not contain "%"'
        ;
      END IF;

      v_type := jsonb_typeof( c_param->parameter_name );
      IF v_type IN ( 'array', 'object' ) THEN
        RAISE EXCEPTION '% is not supported as a parameter type', v_type
          USING DETAIL = format( $$paramater %s = %s$$, parameter_name, value )
        ;
      END IF;
    END LOOP;
  END;

  /*
   * Look for things to replace
   */
  DECLARE
    c_parse CONSTANT text[] := string_to_array( template::text, '%' );
    c_alen CONSTANT int := array_length( c_parse, 1 );

    /*
     * TODO: Instead of trying to track exact template position, it would be
     * easier to just track the accumulated length of every c_parse element
     * we've seen. That can be converted to template position by simply adding
     * (v_pos-1) * length('%').
     */
    v_template_pos int := 1 + length(c_parse[1]); -- Start at 1 and account for c_parse[1]

    v_pos int := 2; -- We handle first element specially
    v_format_option_position int;
    v_last_parameter_position int;
    v_cur text = ''; -- Needs to start at '' for template position tracking
    v_parameter text;
    v_optional boolean;
    v_format_option text;
    v_value text;
  BEGIN
    /*
     * We have to special-case the first element because we know it must be
     * plain text with no paramaters, or empty if the template starts with '%%'.
     */
    v_return := c_parse[1];
    WHILE v_pos <= c_alen LOOP
      v_template_pos := v_template_pos + 1; -- We just consumed a %
      v_cur := c_parse[v_pos];
      --RAISE WARNING 'v_template_pos = %, v_pos = %, v_cur = %', v_template_pos, v_pos, v_cur;

      /*
       * The %% escape gives us an empty v_cur.
       */
      IF v_cur = '' THEN
        /*
         * If we have the template '1 %% 2 %param%s' then when we hit this
         * condition we're 'inside' the %% (v_pos = 2, v_cur = ''). The code
         * below this IF block depends on v_cur being a parameter name. This
         * means we have to consume the NEXT array element (v_pos = 3) before
         * continuing, because it could ALSO be empty (ie: '%%%param%s'). It
         * could NOT be a parameter though.
         */

        -- Update our position
        v_template_pos = v_template_pos + length(c_parse[v_pos + 1]) + 1;
        -- v_cur will immediately be reset
        
        -- Append the % and the next array element
        v_return := v_return || '%' || c_parse[v_pos + 1];
        v_pos := v_pos + 2;
        CONTINUE;
      END IF;

      /*
       * Since we don't allow % in a parameter name, we know that v_cur IS THE NAME OF A PARAMETER.
       */
      v_last_parameter_position := v_template_pos - 1; -- -1 for the '%'
      v_parameter := v_cur;
      v_pos := v_pos + 1;
      IF v_pos > c_alen THEN
        RAISE EXCEPTION 'Reached end of template while processing parameters'
          USING HINT = E'Parameters must match the format "%parameter_name%[O]T" where T is s, I or L\n'
            || 'and O (if present) means the parameter is optional.'
        ;
      END IF;

      v_template_pos = v_template_pos + length(v_cur) + 1;
      v_cur := c_parse[v_pos];
      --RAISE WARNING 'v_template_pos = %, v_pos = %, v_cur = %', v_template_pos, v_pos, v_cur;
      /*
       * At this point v_cur IS THE OPTIONS SPECIFIER
       */

      -- This is where to insert support for other format option handling
      -- These ugly shenanigans are to avoid copying a potentially large string multiple times
      v_optional := substr( v_cur, 1, 1 ) = 'O';
      v_format_option_position := CASE v_optional WHEN true THEN 2 WHEN false THEN 1 END;
      v_template_pos = v_template_pos + v_format_option_position - 1; -- -1 because we haven't technically consumed the format specifier yet
      v_format_option = substr( v_cur, v_format_option_position, 1 );
      --RAISE WARNING 'FORMAT OPTION %, v_template_pos = %, v_pos = %, v_format_option_position = %, v_cur = %', v_format_option, v_template_pos, v_pos, v_format_option_position, v_cur;

      --RAISE WARNING 'v_pos = %, v_cur = %, v_format_option = %', v_pos, v_cur, v_format_option;
      IF v_format_option NOT IN ( 's', 'I', 'L' ) THEN
        RAISE EXCEPTION 'Unexpected character "%" in format specifier "%"'
            , v_format_option
            , substr(v_cur, 1, v_format_option_position )
          USING DETAIL = format( 'parameter "%s" at template position %s', v_parameter, v_last_parameter_position )
        ;
      END IF;

      IF v_optional THEN
        IF v_format_option = 'I' THEN
          RAISE EXCEPTION 'SQL identifier format option ("I") not allowed with optional parameters'
            USING ERRCODE = 'null_value_not_allowed'
              , HINT = 'SQL identifiers can not be NULL or empty, so identifier formats may not be optional.'
              , DETAIL = format( 'parameter "%s" at template position %s', v_parameter, v_last_parameter_position )
          ;
        END IF;
        -- c_param->v_parameter will ONLY be NULL if v_parameter doesn't exist in the document
      ELSIF (c_param->v_parameter) IS NULL THEN
        RAISE EXCEPTION 'parameter "%" not found', v_parameter
          USING DETAIL = format( 'at template position %s', v_last_parameter_position )
        ;
      END IF;


      -- Now that we've consumed the format specifier, update v_template_pos and grab our value
      v_template_pos := v_template_pos + 1;
      v_value := c_param->>v_parameter;

      /*
      RAISE WARNING 'v_template_pos = %, v_pos = %, v_parameter = %, v_format_option = %, v_value = %, v_format_option_position = %'
        , v_template_pos, v_pos, v_parameter, v_format_option, v_value, v_format_option_position
        USING DETAIL = format(
          'prior "%s", next: "%s"'
          , substr(template, v_template_pos-20, 20)
          , substr(template, v_template_pos, 20)
        )
      ;
      */
      v_return := v_return
        -- This is the actual replacement
        || format(
          '%' || v_format_option
          , v_value
        )

        -- Remainder of document, up to next '%'
        || substr( v_cur, v_format_option_position + 1 )
      ;
      v_template_pos := v_template_pos + length(v_cur) - v_format_option_position;
      v_pos := v_pos + 1;
    END LOOP;
  END;

  RETURN v_return;
END
$process_body$
  , extract_parameters_options := 'LANGUAGE plpgsql'
  , extract_parameters_body := $extract_body$
DECLARE
  c_param CONSTANT jsonb := parameters::jsonb;
  a_as text[];
  sql text;
  r record;
BEGIN
  -- DUPLICATED IN BOTH FUNCTIONS
  IF jsonb_typeof(c_param) <> 'object' THEN
    RAISE EXCEPTION 'parameters must be a JSON object, not %', jsonb_typeof(c_param)
      USING DETAIL = format('parameters = %L', c_param)
    ;
  END IF;

  -- Sanity-check parameters
  -- DUPLICATED IN BOTH FUNCTIONS
  DECLARE
    parameter_name text;
    value text;
    v_type text;
  BEGIN
    FOR parameter_name, value IN SELECT * FROM jsonb_each( c_param )
    LOOP
      IF parameter_name ~ '%' THEN
        RAISE EXCEPTION
          USING DETAIL = 'parameter_name ' || parameter_name
            -- MESSAGE instead of trying to escape %
            , MESSAGE = 'parameter names may not contain "%"'
        ;
      END IF;

      v_type := jsonb_typeof( c_param->parameter_name );
      IF v_type IN ( 'array', 'object' ) THEN
        RAISE EXCEPTION '% is not supported as a parameter type', v_type
          USING DETAIL = format( $$paramater %s = %s$$, parameter_name, value )
        ;
      END IF;

      -- THIS IS SPECIFIC TO extract_parametrs
      IF parameter_name = ANY( extract_list ) THEN
        a_as := a_as || format(
          '%I %s'
          , parameter_name
          , CASE
              WHEN v_type IN( 'string', 'null' ) THEN 'text'
              WHEN v_type = 'number' THEN 'numeric'
              -- array and object can't happen
              ELSE v_type
            END
        );
      END IF;
    END LOOP;
  END;

  sql := 'SELECT * FROM jsonb_to_record($1) AS j(' || array_to_string( a_as, ', ' ) || ')';
  RAISE DEBUG 'sql = %', sql;
  EXECUTE sql INTO r USING c_param;
  RETURN row_to_json(r)::jsonb;
END
$extract_body$
);

-- vi: expandtab ts=2 sw=2
