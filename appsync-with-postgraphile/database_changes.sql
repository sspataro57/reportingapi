------------- collab.GetActivityIDsFunc ----------------------------

drop function if exists collab.GetActivityIDsFunc;

CREATE OR REPLACE FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
RETURNS TABLE (ret_id uuid, distance double precision)
AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT DISTINCT ON (collab.activities.id)
                    collab.activities.id,
                    ST_DistanceSphere(ST_MakePoint(longitude, latitude),
                    ST_MakePoint(p_longitude, p_latitude)) * 0.000621371 as distance
                 FROM collab.activities
                 WHERE portal_id = p_portal_id::uuid
                   AND (
                        p_status IS NULL OR
                        (
                            (p_status = 'published' AND status = p_status) OR
                            (p_status != 'published' AND status != 'published')
                        )
                    )
                   AND (p_start_time IS NULL OR created > p_start_time )
                   AND (p_end_time IS NULL OR created < p_end_time)
                   AND (p_focus_areas IS NULL OR focus_areas @> p_focus_areas)
                   AND (p_program_id IS NULL OR id IN (SELECT activity_id FROM collab.activity_to_programs WHERE program_id = ANY (CAST(p_program_id AS uuid[]))))
                   AND (p_unit_id IS NULL OR id IN (SELECT activity_id FROM collab.activity_to_units WHERE unit_id = ANY (CAST(p_unit_id AS uuid[]))))
                   AND (
                       p_longitude IS NULL AND p_latitude IS NULL
                       OR (
                           (p_virtual_location = true AND (NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id) OR EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)))
                           OR (p_virtual_location = false AND NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true) AND ST_DistanceSphere(ST_MakePoint(longitude, latitude), ST_MakePoint(p_longitude, p_latitude)) * 0.000621371 < p_distance)
                       )
                   )
                   AND (p_virtual_location IS NULL OR (p_virtual_location = true AND EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)) OR (p_virtual_location = false AND NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)))
                   AND (p_type IS NULL OR lower(type) = p_type);
END;
$$ LANGUAGE plpgsql;


comment on function collab.GetActivityIDsFunc(varchar, text, timestamp, timestamp, jsonb, character varying[],character varying[], double precision, double precision, double precision, boolean,varchar) is '@omit: "create,update,delete"';

-------------- collab.GetActivityCountFunc ----------------------------
drop function if exists collab.GetActivityCountFunc;

CREATE OR REPLACE FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
RETURNS TABLE (portalid varchar, count integer)
AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT p_portal_id, count(tbl.ret_id)::integer 
                    FROM (SELECT ret_id
                    FROM collab.GetActivityIDsFunc(p_portal_id,
                                                    p_status,
                                                    p_start_time,
                                                    p_end_time,
                                                    p_focus_areas,
                                                    p_program_id,p_unit_id,
                                                    p_longitude,
                                                    p_latitude,
                                                    p_distance,
                                                    p_virtual_location,
                                                    p_type)
                    ) tbl;
END;
$$ LANGUAGE plpgsql;



GRANT EXECUTE ON FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_unit_id varchar[],
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;

GRANT EXECUTE ON FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_unit_id varchar[],
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;

COMMENT ON FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_unit_id varchar[],
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetActivityCountFunc';

COMMENT ON FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_unit_id varchar[],
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean,
    p_type varchar
) IS E'@omit: "create,update,delete"';


-------------- collab.GetActivitiesFunc ----------------------------

drop function if exists collab.GetActivitiesFunc;
CREATE OR REPLACE FUNCTION collab.GetActivitiesFunc(
    p_portal_id varchar,
    p_sort_by text DEFAULT 'created',
    p_sort_dir text DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
	p_include_address boolean DEFAULT NULL,
	p_include_funders boolean DEFAULT NULL,
	p_include_communities boolean DEFAULT NULL,
	p_include_units boolean DEFAULT NULL,
	p_include_programs boolean DEFAULT NULL,
	p_include_faculties boolean DEFAULT NULL
)
RETURNS TABLE (
    insert_timestamp       timestamp with time zone,
    id                     uuid,
    author_id              uuid,
    created                timestamp with time zone,
    modified               timestamp with time zone,
    archived               boolean,
    deleted                boolean,
    slug                   char(9),
    name                   text,
    description            text,
    start_time             timestamp with time zone,
    end_time               timestamp with time zone,
    latitude               numeric(8, 6),
    longitude              numeric(9, 6),
    logo_id                uuid,
    logo_url               text,
    url                    text,
    product_id             integer,
    external_id            varchar(100),
    mutual_benefit         boolean,
    reciprocity            boolean,
    scholarship            boolean,
    teaching               boolean,
    scholarly_research     boolean,
    student_participation  boolean,
    student_members        integer,
    student_members_actual boolean,
    student_hours          integer,
    faculty_participation  boolean,
    faculty_members        integer,
    reflections            boolean,
    reflection_description text,
    frequency              integer,
    contact_phone_public   boolean,
    contact_email_public   boolean,
    irb_protocol           boolean,
    irb_protocol_id        text,
    individuals_served     integer,
    community_insight      text,
    goals_feedback         text,
    focuses                text[],
    focus_areas            jsonb,
    populations            text[],
    organizing_framework   text[],
    events_services        text[],
    scholarship_types      text[],
    expected_scholarly_outputs text[],
    achieved_scholarly_outputs text[],
    expected_ps_outputs    text[],
    achieved_ps_outputs    text[],
    expected_outcomes      text[],
    achieved_outcomes      text[],
    expected_impacts       text[],
    achieved_impacts       text[],
    research_types         text[],
    external_partners      boolean,
    student_hours_actual   boolean,
    modified_by            uuid,
    status                 text,
    contact_firstname      text,
    contact_lastname       text,
    contact_email          text,
    contact_office         text,
    contact_phone          text,
    contact_private_email  boolean,
    contact_private_name   boolean,
    primary_activity       text,
    type                   text,
    featured               timestamp with time zone,
    contact_private_phone  boolean,
    portal_id              uuid,
    activity_lead          uuid,
    activity_lead_status   text,
    distance               float,
    address                text,
    funders                text,
    communities            text,
    units                  text,
    programs               text,
    faculties              text
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY
        SELECT *,
            CASE WHEN p_include_address THEN (SELECT address::text FROM collab.getActivityAddressFunc(id::varchar)) END AS address,
            CASE WHEN p_include_funders THEN (SELECT community_funders::text FROM collab.getFundersActivityFunc(id::varchar)) END AS funders,
            CASE WHEN p_include_communities THEN (SELECT communities::text FROM collab.getActivityCommunityOrgFunc(id::varchar)) END AS communities,
            CASE WHEN p_include_units THEN (SELECT units FROM collab.getActivityUnitsFunc(id::varchar)) END AS units,
            CASE WHEN p_include_programs THEN (SELECT programs FROM collab.getActivityProgramsFunc(id::varchar)) END AS programs,
            CASE WHEN p_include_faculties THEN (SELECT faculty FROM collab.getActivityFacultyStaffFunc(id::varchar)) END AS faculties
        FROM (SELECT DISTINCT ON (id) *
                FROM (SELECT collab.activities.*,ids.distance
                        FROM collab.activities INNER JOIN
                        (SELECT ret_id,distance FROM collab.GetActivityIDsFunc(
                                    p_portal_id,
                                    p_status,
                                    p_start_time,
                                    p_end_time,
                                    p_focus_areas,
                                    p_program_id,p_unit_id,
                                    p_longitude,
                                    p_latitude,
                                    p_distance,
                                    p_virtual_location,
                                    p_type)
                            ) ids ON collab.activities.id = ids.ret_id) AS tbl1) tbl
    ORDER BY
        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (name) END ASC,
		CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN (name) END DESC,
		CASE WHEN (p_sort_by = 'created' OR p_sort_by IS NULL) AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (created) END ASC,
		CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN (created) END DESC
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;



GRANT EXECUTE ON FUNCTION collab.GetActivitiesFunc(
    p_portal_id varchar,
    p_sort_by text,
    p_sort_dir text,
    p_limit integer,
    p_offset integer,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean,
    p_type varchar,
	p_include_address boolean,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean
) TO api_readonly;


COMMENT ON FUNCTION collab.GetActivitiesFunc(
    p_portal_id varchar,
    p_sort_by text,
    p_sort_dir text,
    p_limit integer,
    p_offset integer,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean,
    p_type varchar,
	p_include_address boolean,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean
) IS E'@name GetActivitiesFunc';

------------------------  collab.getCommunityPartnersCountFunc  --------------------

drop function if exists collab.getCommunityPartnersCountFunc;
CREATE OR REPLACE FUNCTION collab.getCommunityPartnersCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
     RETURNS integer
AS
$$
    # variable_conflict use_column
DECLARE
    ret_count integer;
BEGIN
    SELECT count(distinct org.id)::integer
    INTO ret_count
                 from collab.v_activity_to_community_partners p
                          inner join
                      (SELECT ret_id, distance
                       FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas,
                                                      p_program_id, p_unit_id, p_longitude, p_latitude, p_distance,
                                                      p_virtual_location,p_type)) ids
                      on p.activity_id = ids.ret_id
                          inner join collab.organizations org on p.community_id = org.id;
        RETURN ret_count;
END;
$$ LANGUAGE plpgsql;



GRANT EXECUTE ON FUNCTION collab.getCommunityPartnersCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getCommunityPartnersCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetCommunityPartnersCountFunc';



 


----------------------------   GetFacStaffCountFunc -----------------------------
drop function if exists collab.GetFacStaffCountFunc;
CREATE OR REPLACE FUNCTION collab.GetFacStaffCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
RETURNS integer
AS $$
DECLARE
    ret_count integer;
BEGIN
    SELECT count(distinct id)::integer
    INTO ret_count
    FROM (SELECT u.id, u.firstname, u.lastname, em.email, u.insert_timestamp,
                    ROW_NUMBER() OVER (PARTITION BY u.id ORDER BY u.insert_timestamp DESC) as row_num
            FROM users.users u
            INNER JOIN users.user_emails em ON u.id = em.user_id
            INNER JOIN users.user_associations ua ON u.id = ua.user_id
                INNER JOIN (
                SELECT ret_id, distance
                        FROM collab.GetActivityIDsFunc(
                            p_portal_id,
                            p_status,
                            p_start_time,
                            p_end_time,
                            p_focus_areas,
                            p_program_id,
                            p_unit_id,
                            p_longitude,
                            p_latitude,
                            p_distance,
                            p_virtual_location,
                            p_type
                        )
                ) ids ON ua.entity_id = ids.ret_id AND ua.type <> 'proxy'
            ) subquery
            WHERE subquery.row_num = 1;

    RETURN ret_count;
END;
$$ LANGUAGE plpgsql;


GRANT EXECUTE ON FUNCTION collab.GetFacStaffCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.GetFacStaffCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetFacStaffCountFunc';

drop function if exists collab.GetFacStaffFunc;
CREATE OR REPLACE FUNCTION collab.GetFacStaffFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'firstname,lastname',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
RETURNS TABLE (
    user_id text,
    firstname text,
    lastname text,
    email text
)
AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT id::text, firstname, lastname, email
                    FROM (
                    SELECT u.id, u.firstname, u.lastname, em.email, u.insert_timestamp,
                            ROW_NUMBER() OVER (PARTITION BY u.id ORDER BY u.insert_timestamp DESC) as row_num
                    FROM users.users u
                    INNER JOIN users.user_emails em ON u.id = em.user_id
                    INNER JOIN users.user_associations ua ON u.id = ua.user_id
                        INNER JOIN (
                        SELECT ret_id, distance
                              FROM collab.GetActivityIDsFunc(
                                  p_portal_id,
                                  p_status,
                                  p_start_time,
                                  p_end_time,
                                  p_focus_areas,
                                  p_program_id,
                                  p_unit_id,
                                  p_longitude,
                                  p_latitude,
                                  p_distance,
                                  p_virtual_location,
                                  p_type
                              )
                        ) ids ON ua.entity_id = ids.ret_id AND ua.type <> 'proxy'
                    ) subquery
                    WHERE subquery.row_num = 1 
                    ORDER BY
                        CASE WHEN p_sort_by = 'firstname' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (firstname,lastname) END ASC,
                        CASE WHEN p_sort_by = 'firstname' AND upper(p_sort_dir) = 'DESC' THEN (firstname,lastname) END DESC,
                        CASE WHEN p_sort_by = 'lastname' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (lastname,firstname) END ASC,
                        CASE WHEN p_sort_by = 'lastname' AND upper(p_sort_dir) = 'DESC' THEN (lastname,firstname) END DESC,
                        CASE WHEN p_sort_by = 'email' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (email,firstname,lastname) END ASC,
                        CASE WHEN p_sort_by = 'email' AND upper(p_sort_dir) = 'DESC' THEN (email,firstname,lastname) END DESC,
                        CASE WHEN p_sort_by IS NULL THEN (firstname,lastname) END ASC                  
                    LIMIT p_limit
                    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;


GRANT EXECUTE ON FUNCTION collab.GetFacStaffFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.GetFacStaffFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
)  IS E'@name GetFacStaffFunc';


---------------  collab.getCommunityPartnersFunc -----------------------
 
drop function if exists collab.getCommunityPartnersFunc;
CREATE OR REPLACE FUNCTION collab.getCommunityPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'firstname,lastname',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
    RETURNS TABLE
            (
                insert_timestamp            TIMESTAMP with time zone,
                id                          text,
                type                        text,
                author_id                   text,
                created                     TIMESTAMP with time zone,
                modified                    TIMESTAMP with time zone,
                archived                    BOOLEAN,
                deleted                     BOOLEAN,
                slug                        CHAR(9),
                vanity                      TEXT,
                name                        TEXT,
                description                 TEXT,
                latitude                    NUMERIC(8, 6),
                longitude                   NUMERIC(9, 6),
                logo_id                     UUID,
                logo_url                    TEXT,
                url                         TEXT,
                external_id                 VARCHAR(100),
                portal                      BOOLEAN,
                welcome_message             TEXT,
                office_name                 TEXT,
                allow_offline               BOOLEAN,
                mission_statement           TEXT,
                email                       TEXT,
                phone                       TEXT,
                fax                         TEXT,
                disable_email_notifications BOOLEAN,
                registrar_url               TEXT,
                course_catalog_url          TEXT,
                street                      TEXT,
                street2                     TEXT,
                city                        TEXT,
                state                       VARCHAR(3),
                county                      TEXT,
                zipcode                     VARCHAR(25),
                zipcode_addon               INTEGER,
                country                     CHAR(2),
                modified_by                 TEXT,
                status                      TEXT,
                parent_id                   TEXT
            )
AS
$$
    # variable_conflict use_column
BEGIN
    RETURN QUERY SELECT *
                    FROM (SELECT DISTINCT ON (org.id)
                            org.insert_timestamp,
                            org.id::text,
                            org.type,
                            org.author_id::text,
                            org.created,
                            org.modified,
                            org.archived,
                            org.deleted,
                            org.slug,
                            org.vanity,
                            org.name,
                            org.description,
                            org.latitude,
                            org.longitude,
                            org.logo_id,
                            org.logo_url,
                            org.url,
                            org.external_id,
                            org.portal,
                            org.welcome_message,
                            org.office_name,
                            org.allow_offline,
                            org.mission_statement,
                            org.email,
                            org.phone,
                            org.fax,
                            org.disable_email_notifications,
                            org.registrar_url,
                            org.course_catalog_url,
                            org.street,
                            org.street2,
                            org.city,
                            org.state,
                            org.county,
                            org.zipcode,
                            org.zipcode_addon,
                            org.country,
                            org.modified_by::text,
                            org.status,
                            org.parent_id::text
                    from collab.v_activity_to_community_partners p
                            inner join
                        (SELECT ret_id, distance
                        FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas,
                                                        p_program_id, p_unit_id, p_longitude, p_latitude, p_distance,
                                                        p_virtual_location,p_type)) ids
                        on p.activity_id = ids.ret_id
                            inner join collab.organizations org on p.community_id = org.id) AS tbl
                ORDER BY
                    CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (tbl.name) END ASC,
                    CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN (tbl.name) END DESC,
                    CASE WHEN (p_sort_by = 'created' OR p_sort_by IS NULL) AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (tbl.created) END ASC,
                    CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN (tbl.created) END DESC,  
                    CASE WHEN p_sort_by IS NULL THEN tbl.created END ASC                     
                LIMIT p_limit
                OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;



GRANT EXECUTE ON FUNCTION collab.getCommunityPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getCommunityPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetCommunityPartnersFunc';


------------------  GetInstitutionalPartnersCountFunc --------------------

drop function if exists collab.getInstitutionalPartnersCountFunc;
CREATE OR REPLACE FUNCTION collab.getInstitutionalPartnersCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
     RETURNS integer
AS
$$
    # variable_conflict use_column
DECLARE
    ret_count integer;
BEGIN
    SELECT count(distinct org.id)
    INTO ret_count
                 from collab.activity_to_institutional_partners p
                          inner join
                      (SELECT ret_id, distance
                       FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas,
                                                      p_program_id, p_unit_id, p_longitude, p_latitude, p_distance,
                                                      p_virtual_location,p_type)) ids
                      on p.activity_id = ids.ret_id
                          inner join collab.organizations org on p.institution_id = org.id;
        RETURN ret_count;
END;
$$ LANGUAGE plpgsql;



GRANT EXECUTE ON FUNCTION collab.getInstitutionalPartnersCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getInstitutionalPartnersCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetInstitutionalPartnersCountFunc';





-------------------- collab.getInstitutionalPartnersFunc ------------------------


drop function if exists collab.getInstitutionalPartnersFunc;
CREATE OR REPLACE FUNCTION collab.getInstitutionalPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'firstname,lastname',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
    RETURNS TABLE
            (
                insert_timestamp            TIMESTAMP with time zone,
                id                          text,
                type                        text,
                author_id                   text,
                created                     TIMESTAMP with time zone,
                modified                    TIMESTAMP with time zone,
                archived                    BOOLEAN,
                deleted                     BOOLEAN,
                slug                        CHAR(9),
                vanity                      TEXT,
                name                        TEXT,
                description                 TEXT,
                latitude                    NUMERIC(8, 6),
                longitude                   NUMERIC(9, 6),
                logo_id                     UUID,
                logo_url                    TEXT,
                url                         TEXT,
                external_id                 VARCHAR(100),
                portal                      BOOLEAN,
                welcome_message             TEXT,
                office_name                 TEXT,
                allow_offline               BOOLEAN,
                mission_statement           TEXT,
                email                       TEXT,
                phone                       TEXT,
                fax                         TEXT,
                disable_email_notifications BOOLEAN,
                registrar_url               TEXT,
                course_catalog_url          TEXT,
                street                      TEXT,
                street2                     TEXT,
                city                        TEXT,
                state                       VARCHAR(3),
                county                      TEXT,
                zipcode                     VARCHAR(25),
                zipcode_addon               INTEGER,
                country                     CHAR(2),
                modified_by                 TEXT,
                status                      TEXT,
                parent_id                   TEXT
            )
AS
$$
    # variable_conflict use_column
BEGIN
    RETURN QUERY SELECT *
                    FROM (SELECT DISTINCT ON (org.id)
                            org.insert_timestamp,
                            org.id::text,
                            org.type,
                            org.author_id::text,
                            org.created,
                            org.modified,
                            org.archived,
                            org.deleted,
                            org.slug,
                            org.vanity,
                            org.name,
                            org.description,
                            org.latitude,
                            org.longitude,
                            org.logo_id,
                            org.logo_url,
                            org.url,
                            org.external_id,
                            org.portal,
                            org.welcome_message,
                            org.office_name,
                            org.allow_offline,
                            org.mission_statement,
                            org.email,
                            org.phone,
                            org.fax,
                            org.disable_email_notifications,
                            org.registrar_url,
                            org.course_catalog_url,
                            org.street,
                            org.street2,
                            org.city,
                            org.state,
                            org.county,
                            org.zipcode,
                            org.zipcode_addon,
                            org.country,
                            org.modified_by::text,
                            org.status,
                            org.parent_id::text
                    from collab.activity_to_institutional_partners p
                            inner join
                        (SELECT ret_id, distance
                        FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas,
                                                        p_program_id, p_unit_id, p_longitude, p_latitude, p_distance,
                                                        p_virtual_location,p_type)) ids
                        on p.activity_id = ids.ret_id
                            inner join collab.organizations org on p.institution_id = org.id) AS tbl
                ORDER BY
                    CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (tbl.name) END ASC,
                    CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN (tbl.name) END DESC,
                    CASE WHEN (p_sort_by = 'created' OR p_sort_by IS NULL) AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (tbl.created) END ASC,
                    CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN (tbl.created) END DESC,  
                    CASE WHEN p_sort_by IS NULL THEN tbl.created END ASC                  
                LIMIT p_limit
                OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;



GRANT EXECUTE ON FUNCTION collab.getInstitutionalPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getInstitutionalPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetInstitutionalPartnersFunc';


----------------------- UNIT partners count --------------------------------
drop function if exists collab.GetUnitPartnersCountFunc;
CREATE OR REPLACE FUNCTION collab.GetUnitPartnersCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)    RETURNS integer
AS $$
    # variable_conflict use_column
DECLARE
    ret_count integer;
BEGIN
    SELECT count(distinct u.id)::integer
    INTO ret_count
FROM collab.units u
         inner join collab.activity_to_units au on u.id = au.unit_id
         inner join
     (SELECT ret_id,distance FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id,p_unit_id, p_longitude, p_latitude, p_distance, p_virtual_location,p_type)) ids
     on au.activity_id = ids.ret_id;
   RETURN ret_count;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.GetUnitPartnersCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.GetUnitPartnersCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetUnitPartnersCountFunc';

----------------------- UNIT partners --------------------------------


drop function if exists collab.GetUnitPartnersFunc;
CREATE OR REPLACE FUNCTION collab.GetUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL

) RETURNS TABLE (
    insert_timestamp          timestamp with time zone,
    id                        text,
    author_id                 text,
    created                   timestamp with time zone,
    modified                  timestamp with time zone,
    archived                  boolean,
    deleted                   boolean,
    type                      text,
    name                      text,
    description               text,
    logo_url                  text,
    url                       text,
    external_id               varchar(100),
    bypass_profile_moderation boolean,
    parent_id                 text,
    portal_id                 text,
    contact_firstname         text,
    contact_lastname          text,
    contact_phone             text,
    contact_email             text
) AS $$
BEGIN
    RETURN QUERY SELECT *
                    FROM (SELECT
                                u.insert_timestamp,
                                u.id::text,
                                u.author_id::text,
                                u.created,
                                u.modified,
                                u.archived,
                                u.deleted,
                                u.type,
                                u.name,
                                u.description,
                                u.logo_url,
                                u.url,
                                u.external_id,
                                u.bypass_profile_moderation,
                                u.parent_id::text,
                                u.portal_id::text,
                                u.contact_firstname,
                                u.contact_lastname,
                                u.contact_phone,
                                u.contact_email
                        FROM collab.v_units u
                                inner join collab.v_activity_to_units au on u.id = au.unit_id
                                inner join
                            (SELECT ret_id,distance FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id,p_unit_id, p_longitude, p_latitude, p_distance, p_virtual_location,p_type)) ids
                            on au.activity_id = ids.ret_id
                        group by
                                u.insert_timestamp,
                                u.id::text,
                                u.author_id::text,
                                u.created,
                                u.modified,
                                u.archived,
                                u.deleted,
                                u.type,
                                u.name,
                                u.description,
                                u.logo_url,
                                u.url,
                                u.external_id,
                                u.bypass_profile_moderation,
                                u.parent_id::text,
                                u.portal_id::text,
                                u.contact_firstname,
                                u.contact_lastname,
                                u.contact_phone,
                                u.contact_email) AS tbl
                ORDER BY
                    CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (tbl.name) END ASC,
                    CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN (tbl.name) END DESC,
                    CASE WHEN (p_sort_by = 'created' OR p_sort_by IS NULL) AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (tbl.created) END ASC,
                    CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN (tbl.created) END DESC,  
                    CASE WHEN p_sort_by IS NULL THEN tbl.created END ASC                  
                LIMIT p_limit
                OFFSET p_offset; 
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetUnitPartnersFunc';


------------------ GetActivityFundersCountFunc -------------------------

drop function if exists collab.GetActivityFundersCountFunc;
CREATE OR REPLACE FUNCTION collab.GetActivityFundersCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_founder_source varchar DEFAULT NULL
)    RETURNS integer
AS $$
    # variable_conflict use_column
DECLARE
    ret_count integer;
BEGIN
    SELECT count(distinct fund.funder_id)::integer
    INTO ret_count
    FROM collab.v_activity_funders fund
             inner join (SELECT ret_id,distance FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id,p_unit_id, p_longitude, p_latitude, p_distance, p_virtual_location,p_type)) ids
                        on fund.activity_id = ids.ret_id
    WHERE (p_founder_source IS NULL OR fund.source = p_founder_source);
     RETURN ret_count;
END;
$$ LANGUAGE plpgsql;


GRANT EXECUTE ON FUNCTION collab.GetActivityFundersCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_founder_source varchar
) TO api_readonly;

drop function if exists collab.GetUnitPartnersFunc;
CREATE OR REPLACE FUNCTION collab.GetUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
) RETURNS TABLE (
    insert_timestamp          timestamp with time zone,
    id                        text,
    author_id                 text,
    created                   timestamp with time zone,
    modified                  timestamp with time zone,
    archived                  boolean,
    deleted                   boolean,
    type                      text,
    name                      text,
    description               text,
    logo_url                  text,
    url                       text,
    external_id               varchar(100),
    bypass_profile_moderation boolean,
    parent_id                 text,
    portal_id                 text,
    contact_firstname         text,
    contact_lastname          text,
    contact_phone             text,
    contact_email             text
) AS $$
BEGIN
    RETURN QUERY SELECT
        u.insert_timestamp,
        u.id::text,
        u.author_id::text,
        u.created,
        u.modified,
        u.archived,
        u.deleted,
        u.type,
        u.name,
        u.description,
        u.logo_url,
        u.url,
        u.external_id,
        u.bypass_profile_moderation,
        u.parent_id::text,
        u.portal_id::text,
        u.contact_firstname,
        u.contact_lastname,
        u.contact_phone,
        u.contact_email
FROM collab.units u
         inner join collab.activity_to_units au on u.id = au.unit_id
         inner join
     (SELECT ret_id,distance FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id,p_unit_id, p_longitude, p_latitude, p_distance, p_virtual_location,p_type)) ids
     on au.activity_id = ids.ret_id
   group by
        u.insert_timestamp,
        u.id::text,
        u.author_id::text,
        u.created,
        u.modified,
        u.archived,
        u.deleted,
        u.type,
        u.name,
        u.description,
        u.logo_url,
        u.url,
        u.external_id,
        u.bypass_profile_moderation,
        u.parent_id::text,
        u.portal_id::text,
        u.contact_firstname,
        u.contact_lastname,
        u.contact_phone,
        u.contact_email     
    ORDER BY CASE
        WHEN p_sort_by = 'name' THEN u.id::text
        WHEN p_sort_by = 'type' THEN u.type::text
        WHEN p_sort_by = 'contact_lastname' THEN  u.contact_lastname::text
        ELSE u.name
    END
    || ' ' || p_sort_dir
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetUnitPartnersFunc';
COMMENT ON FUNCTION collab.GetActivityFundersCountFunc(    
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_founder_source varchar
) IS E'@name GetActivityFundersCountFunc';

 



----------------  GetActivityFundersFunc   ---------------------

drop function if exists collab.GetActivityFundersFunc;
CREATE OR REPLACE FUNCTION collab.GetActivityFundersFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_founder_source varchar DEFAULT NULL
)
RETURNS TABLE (
    insert_timestamp TIMESTAMP WITH TIME ZONE,
    modified TIMESTAMP WITH TIME ZONE,
    activity_id TEXT,
    funder_id TEXT,
    name TEXT,
    start_ts TIMESTAMP WITH TIME ZONE,
    end_ts TIMESTAMP WITH TIME ZONE,
    amount NUMERIC,
    source TEXT,
    deleted BOOLEAN
) AS $$
BEGIN
    RETURN QUERY SELECT
        fund.insert_timestamp,
        fund.modified,
        fund.activity_id::text,
        fund.funder_id::text,
        fund.name,
        fund.start_ts,
        fund.end_ts,
        fund.amount,
        fund.source,
        fund.deleted
    FROM collab.v_activity_funders fund
             inner join (SELECT ret_id,distance FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id,p_unit_id, p_longitude, p_latitude, p_distance, p_virtual_location,p_type)) ids
                        on fund.activity_id = ids.ret_id
    WHERE (p_founder_source IS NULL OR fund.source = p_founder_source)
    ORDER BY
        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (fund.name) END ASC,
		CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN (fund.name) END DESC,
		CASE WHEN (p_sort_by = 'modified' OR p_sort_by IS NULL) AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (fund.modified) END ASC,
		CASE WHEN p_sort_by = 'modified' AND upper(p_sort_dir) = 'DESC' THEN (fund.modified) END DESC,  
        CASE WHEN p_sort_by IS NULL THEN fund.modified END ASC 
    LIMIT p_limit
    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;


GRANT EXECUTE ON FUNCTION collab.GetActivityFundersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_founder_source varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.GetActivityFundersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_founder_source varchar
) IS E'@name GetActivityFundersFunc';
 


 ----------------------- unit partners top count
 
drop function if exists collab.GetTopUnitPartnersFunc;
CREATE OR REPLACE FUNCTION collab.GetTopUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL

) RETURNS TABLE (
    id                        text,
    author_id                 text,
    created                   TIMESTAMP WITH TIME ZONE,
    archived                  boolean,
    deleted                   boolean,
    type                      text,
    name                      text,
    description               text,
    logo_url                  text,
    url                       text,
    external_id               varchar(100),
    bypass_profile_moderation boolean,
    parent_id                 text,
    portal_id                 text,
    contact_firstname         text,
    contact_lastname          text,
    contact_phone             text,
    contact_email             text,
    countActivities           integer          
) AS $$
BEGIN
    RETURN QUERY SELECT *
        FROM (SELECT
                    u.id::text,
                    u.author_id::text,
                    u.created,
                    u.archived,
                    u.deleted,
                    u.type,
                    u.name,
                    u.description,
                    u.logo_url,
                    u.url,
                    u.external_id,
                    u.bypass_profile_moderation,
                    u.parent_id::text,
                    u.portal_id::text,
                    u.contact_firstname,
                    u.contact_lastname,
                    u.contact_phone,
                    u.contact_email,
                    count(au.activity_id)::integer as countActivities
            FROM collab.v_units u
                    inner join collab.v_activity_to_units au on u.id = au.unit_id
                    inner join
                (SELECT ret_id,distance FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id,p_unit_id, p_longitude, p_latitude, p_distance, p_virtual_location,p_type)) ids
                on au.activity_id = ids.ret_id
            group by
                    u.id::text,
                    u.author_id::text,
                    u.created,
                    u.archived,
                    u.deleted,
                    u.type,
                    u.name,
                    u.description,
                    u.logo_url,
                    u.url,
                    u.external_id,
                    u.bypass_profile_moderation,
                    u.parent_id::text,
                    u.portal_id::text,
                    u.contact_firstname,
                    u.contact_lastname,
                    u.contact_phone,
                    u.contact_email) AS tbl
                ORDER BY
                    CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (tbl.name) END ASC,
                    CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN (tbl.name) END DESC,
                    CASE WHEN (p_sort_by = 'created' OR p_sort_by IS NULL) AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN (tbl.created) END ASC,
                    CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN (tbl.created) END DESC,  
                    CASE WHEN p_sort_by IS NULL THEN tbl.created END ASC                  
                LIMIT p_limit
                OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getTopUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getTopUnitPartnersFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name GetTopUnitPartnersFunc';

----------------------- institutional partners Activities
 
drop function if exists collab.getinstitutionalpartnersActivitiesfunc;
CREATE OR REPLACE FUNCTION collab.getinstitutionalpartnersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_institution_id varchar DEFAULT NULL,
	p_include_funders boolean DEFAULT NULL,
	p_include_communities boolean DEFAULT NULL,
	p_include_units boolean DEFAULT NULL,
	p_include_programs boolean DEFAULT NULL,
	p_include_faculties boolean DEFAULT NULL,
	p_include_address boolean DEFAULT NULL

) RETURNS TABLE (
    insert_timestamp       timestamp with time zone,
    id                     uuid,
    author_id              uuid,
    created                timestamp with time zone,
    modified               timestamp with time zone,
    archived               boolean,
    deleted                boolean,
    slug                   char(9),
    name                   text,
    description            text,
    start_time             timestamp with time zone,
    end_time               timestamp with time zone,
    latitude               numeric(8, 6),
    longitude              numeric(9, 6),
    logo_id                uuid,
    logo_url               text,
    url                    text,
    product_id             integer,
    external_id            varchar(100),
    mutual_benefit         boolean,
    reciprocity            boolean,
    scholarship            boolean,
    teaching               boolean,
    scholarly_research     boolean,
    student_participation  boolean,
    student_members        integer,
    student_members_actual boolean,
    student_hours          integer,
    faculty_participation  boolean,
    faculty_members        integer,
    reflections            boolean,
    reflection_description text,
    frequency              integer,
    contact_phone_public   boolean,
    contact_email_public   boolean,
    irb_protocol           boolean,
    irb_protocol_id        text,
    individuals_served     integer,
    community_insight      text,
    goals_feedback         text,
    focuses                text[],
    focus_areas            jsonb,
    populations            text[],
    organizing_framework   text[],
    events_services        text[],
    scholarship_types      text[],
    expected_scholarly_outputs text[],
    achieved_scholarly_outputs text[],
    expected_ps_outputs    text[],
    achieved_ps_outputs    text[],
    expected_outcomes      text[],
    achieved_outcomes      text[],
    expected_impacts       text[],
    achieved_impacts       text[],
    research_types         text[],
    external_partners      boolean,
    student_hours_actual   boolean,
    modified_by            uuid,
    status                 text,
    contact_firstname      text,
    contact_lastname       text,
    contact_email          text,
    contact_office         text,
    contact_phone          text,
    contact_private_email  boolean,
    contact_private_name   boolean,
    primary_activity       text,
    type                   text,
    featured               timestamp with time zone,
    contact_private_phone  boolean,
    portal_id              uuid,
    activity_lead          uuid,
    activity_lead_status   text,
    distance               float,
    funders                text,
    communities            text,
    units                  text,
    programs               text,
    faculties              text,
    address                text          
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT *,
                    CASE WHEN p_include_funders THEN (SELECT community_funders::text FROM collab.getFundersActivityFunc(tbl.id::varchar)) END AS funders,
                    CASE WHEN p_include_communities THEN (SELECT communities::text FROM collab.getActivityCommunityOrgFunc(tbl.id::varchar)) END AS communities,
                    CASE WHEN p_include_units THEN (SELECT units FROM collab.getActivityUnitsFunc(tbl.id::varchar)) END AS units,
                    CASE WHEN p_include_programs THEN (SELECT programs FROM collab.getActivityProgramsFunc(tbl.id::varchar)) END AS programs,
                    CASE WHEN p_include_faculties THEN (SELECT faculty FROM collab.getActivityFacultyStaffFunc(tbl.id::varchar)) END AS faculties,
                    CASE WHEN p_include_address THEN (SELECT address::text FROM collab.getActivityAddressFunc(tbl.id::varchar)) END AS address
                    FROM (SELECT DISTINCT ON (act.id) act.*, ids.distance
                            FROM collab.activity_to_institutional_partners p
                            INNER JOIN (SELECT ret_id, distance
                                            FROM collab.GetActivityIDsFunc(
                                                p_portal_id,
                                                p_status,
                                                p_start_time,
                                                p_end_time,
                                                p_focus_areas,
                                                p_program_id,
                                                p_unit_id,
                                                p_longitude,
                                                p_latitude,
                                                p_distance,
                                                p_virtual_location,
                                                p_type)
                            ) ids ON p.activity_id = ids.ret_id
                            INNER JOIN collab.organizations org on p.institution_id = org.id
                            INNER JOIN collab.v_activities act ON act.id = ids.ret_id
                            WHERE (p_institution_id IS NULL OR org.id = p_institution_id::uuid)) AS tbl 
                    ORDER BY
                        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN name END ASC,
                        CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN name END DESC,
                        CASE WHEN p_sort_by = 'created' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN created END ASC,
                        CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN created END DESC,
                        CASE WHEN p_sort_by IS NULL THEN created END ASC                  
                    LIMIT p_limit
                    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getinstitutionalpartnersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_institution_id varchar,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean,
	p_include_address boolean
) TO api_readonly;


COMMENT ON FUNCTION collab.getinstitutionalpartnersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_institution_id varchar,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean,
	p_include_address boolean
) IS E'@name getinstitutionalpartnersActivitiesfunc';


----------------------- faculty staff Activities
 
drop function if exists collab.getfacstaffActivitiesfunc;
CREATE OR REPLACE FUNCTION collab.getfacstaffActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_user_id varchar DEFAULT NULL,
	p_include_funders boolean DEFAULT NULL,
	p_include_communities boolean DEFAULT NULL,
	p_include_units boolean DEFAULT NULL,
	p_include_programs boolean DEFAULT NULL,
	p_include_faculties boolean DEFAULT NULL,
	p_include_address boolean DEFAULT NULL

) RETURNS TABLE (
    insert_timestamp       timestamp with time zone,
    id                     uuid,
    author_id              uuid,
    created                timestamp with time zone,
    modified               timestamp with time zone,
    archived               boolean,
    deleted                boolean,
    slug                   char(9),
    name                   text,
    description            text,
    start_time             timestamp with time zone,
    end_time               timestamp with time zone,
    latitude               numeric(8, 6),
    longitude              numeric(9, 6),
    logo_id                uuid,
    logo_url               text,
    url                    text,
    product_id             integer,
    external_id            varchar(100),
    mutual_benefit         boolean,
    reciprocity            boolean,
    scholarship            boolean,
    teaching               boolean,
    scholarly_research     boolean,
    student_participation  boolean,
    student_members        integer,
    student_members_actual boolean,
    student_hours          integer,
    faculty_participation  boolean,
    faculty_members        integer,
    reflections            boolean,
    reflection_description text,
    frequency              integer,
    contact_phone_public   boolean,
    contact_email_public   boolean,
    irb_protocol           boolean,
    irb_protocol_id        text,
    individuals_served     integer,
    community_insight      text,
    goals_feedback         text,
    focuses                text[],
    focus_areas            jsonb,
    populations            text[],
    organizing_framework   text[],
    events_services        text[],
    scholarship_types      text[],
    expected_scholarly_outputs text[],
    achieved_scholarly_outputs text[],
    expected_ps_outputs    text[],
    achieved_ps_outputs    text[],
    expected_outcomes      text[],
    achieved_outcomes      text[],
    expected_impacts       text[],
    achieved_impacts       text[],
    research_types         text[],
    external_partners      boolean,
    student_hours_actual   boolean,
    modified_by            uuid,
    status                 text,
    contact_firstname      text,
    contact_lastname       text,
    contact_email          text,
    contact_office         text,
    contact_phone          text,
    contact_private_email  boolean,
    contact_private_name   boolean,
    primary_activity       text,
    type                   text,
    featured               timestamp with time zone,
    contact_private_phone  boolean,
    portal_id              uuid,
    activity_lead          uuid,
    activity_lead_status   text,
    distance               float,
    funders                text,
    communities            text,
    units                  text,
    programs               text,
    faculties              text,
    address                text        
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT *,
                    CASE WHEN p_include_funders THEN (SELECT community_funders::text FROM collab.getFundersActivityFunc(tbl.id::varchar)) END AS funders,
                    CASE WHEN p_include_communities THEN (SELECT communities::text FROM collab.getActivityCommunityOrgFunc(tbl.id::varchar)) END AS communities,
                    CASE WHEN p_include_units THEN (SELECT units FROM collab.getActivityUnitsFunc(tbl.id::varchar)) END AS units,
                    CASE WHEN p_include_programs THEN (SELECT programs FROM collab.getActivityProgramsFunc(tbl.id::varchar)) END AS programs,
                    CASE WHEN p_include_faculties THEN (SELECT faculty FROM collab.getActivityFacultyStaffFunc(tbl.id::varchar)) END AS faculties,
                    CASE WHEN p_include_address THEN (SELECT address::text FROM collab.getActivityAddressFunc(tbl.id::varchar)) END AS address
                    FROM (SELECT DISTINCT ON (act.id) act.*, ids.distance
                            FROM users.users u
                            INNER JOIN users.user_emails em ON u.id = em.user_id
                            INNER JOIN users.user_associations ua ON u.id = ua.user_id
                            INNER JOIN (
                                SELECT ret_id, distance
                                    FROM collab.GetActivityIDsFunc(
                                        p_portal_id,
                                        p_status,
                                        p_start_time,
                                        p_end_time,
                                        p_focus_areas,
                                        p_program_id,
                                        p_unit_id,
                                        p_longitude,
                                        p_latitude,
                                        p_distance,
                                        p_virtual_location,
                                        p_type
                                    )
                            ) ids ON ua.entity_id = ids.ret_id AND ua.type <> 'proxy'
                            INNER JOIN collab.activities act ON act.id = ids.ret_id
                            WHERE (p_user_id IS NULL OR u.id = p_user_id::uuid)
                            ) tbl 
                    ORDER BY
                        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN name END ASC,
                        CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN name END DESC,
                        CASE WHEN p_sort_by = 'created' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN created END ASC,
                        CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN created END DESC,
                        CASE WHEN p_sort_by IS NULL THEN created END ASC                  
                    LIMIT p_limit
                    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getfacstaffActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_user_id varchar,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean,
	p_include_address boolean
) TO api_readonly;


COMMENT ON FUNCTION collab.getfacstaffActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_user_id varchar,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean,
	p_include_address boolean
) IS E'@name getfacstaffActivitiesfunc';


----------------------- community partners Activities 
 
drop function if exists collab.getcommunitypartnersActivitiesfunc;
CREATE OR REPLACE FUNCTION collab.getcommunitypartnersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_community_id varchar DEFAULT NULL,
	p_include_funders boolean DEFAULT NULL,
	p_include_communities boolean DEFAULT NULL,
	p_include_units boolean DEFAULT NULL,
	p_include_programs boolean DEFAULT NULL,
	p_include_faculties boolean DEFAULT NULL,
	p_include_address boolean DEFAULT NULL

) RETURNS TABLE (
    insert_timestamp       timestamp with time zone,
    id                     uuid,
    author_id              uuid,
    created                timestamp with time zone,
    modified               timestamp with time zone,
    archived               boolean,
    deleted                boolean,
    slug                   char(9),
    name                   text,
    description            text,
    start_time             timestamp with time zone,
    end_time               timestamp with time zone,
    latitude               numeric(8, 6),
    longitude              numeric(9, 6),
    logo_id                uuid,
    logo_url               text,
    url                    text,
    product_id             integer,
    external_id            varchar(100),
    mutual_benefit         boolean,
    reciprocity            boolean,
    scholarship            boolean,
    teaching               boolean,
    scholarly_research     boolean,
    student_participation  boolean,
    student_members        integer,
    student_members_actual boolean,
    student_hours          integer,
    faculty_participation  boolean,
    faculty_members        integer,
    reflections            boolean,
    reflection_description text,
    frequency              integer,
    contact_phone_public   boolean,
    contact_email_public   boolean,
    irb_protocol           boolean,
    irb_protocol_id        text,
    individuals_served     integer,
    community_insight      text,
    goals_feedback         text,
    focuses                text[],
    focus_areas            jsonb,
    populations            text[],
    organizing_framework   text[],
    events_services        text[],
    scholarship_types      text[],
    expected_scholarly_outputs text[],
    achieved_scholarly_outputs text[],
    expected_ps_outputs    text[],
    achieved_ps_outputs    text[],
    expected_outcomes      text[],
    achieved_outcomes      text[],
    expected_impacts       text[],
    achieved_impacts       text[],
    research_types         text[],
    external_partners      boolean,
    student_hours_actual   boolean,
    modified_by            uuid,
    status                 text,
    contact_firstname      text,
    contact_lastname       text,
    contact_email          text,
    contact_office         text,
    contact_phone          text,
    contact_private_email  boolean,
    contact_private_name   boolean,
    primary_activity       text,
    type                   text,
    featured               timestamp with time zone,
    contact_private_phone  boolean,
    portal_id              uuid,
    activity_lead          uuid,
    activity_lead_status   text,
    distance               float,
    funders                text,
    communities            text,
    units                  text,
    programs               text,
    faculties              text,
    address                text          
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT *,
                    CASE WHEN p_include_funders THEN (SELECT community_funders::text FROM collab.getFundersActivityFunc(tbl.id::varchar)) END AS funders,
                    CASE WHEN p_include_communities THEN (SELECT communities::text FROM collab.getActivityCommunityOrgFunc(tbl.id::varchar)) END AS communities,
                    CASE WHEN p_include_units THEN (SELECT units FROM collab.getActivityUnitsFunc(tbl.id::varchar)) END AS units,
                    CASE WHEN p_include_programs THEN (SELECT programs FROM collab.getActivityProgramsFunc(tbl.id::varchar)) END AS programs,
                    CASE WHEN p_include_faculties THEN (SELECT faculty FROM collab.getActivityFacultyStaffFunc(tbl.id::varchar)) END AS faculties,
                    CASE WHEN p_include_address THEN (SELECT address::text FROM collab.getActivityAddressFunc(tbl.id::varchar)) END AS address
                    FROM (SELECT DISTINCT ON (act.id) act.*, ids.distance
                            FROM collab.v_activity_to_community_partners p
                            INNER JOIN (SELECT ret_id, distance
                                            FROM collab.GetActivityIDsFunc(
                                                p_portal_id,
                                                p_status,
                                                p_start_time,
                                                p_end_time,
                                                p_focus_areas,
                                                p_program_id,
                                                p_unit_id,
                                                p_longitude,
                                                p_latitude,
                                                p_distance,
                                                p_virtual_location,
                                                p_type)
                            ) ids ON p.activity_id = ids.ret_id
                            INNER JOIN collab.organizations org ON p.community_id = org.id
                            INNER JOIN collab.v_activities act ON act.id = ids.ret_id
                            WHERE (p_community_id IS NULL OR org.id = p_community_id::uuid)) AS tbl 
                    ORDER BY
                        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN name END ASC,
                        CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN name END DESC,
                        CASE WHEN p_sort_by = 'created' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN created END ASC,
                        CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN created END DESC,
                        CASE WHEN p_sort_by IS NULL THEN created END ASC                  
                    LIMIT p_limit
                    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getcommunitypartnersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_community_id varchar,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean,
	p_include_address boolean
) TO api_readonly;


COMMENT ON FUNCTION collab.getcommunitypartnersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_community_id varchar,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean,
	p_include_address boolean
) IS E'@name getcommunitypartnersActivitiesfunc';

----------------------- activity funders Activities 
 
drop function if exists collab.getactivityfundersActivitiesfunc;
CREATE OR REPLACE FUNCTION collab.getactivityfundersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_funder_id varchar DEFAULT NULL,
	p_include_funders boolean DEFAULT NULL,
	p_include_communities boolean DEFAULT NULL,
	p_include_units boolean DEFAULT NULL,
	p_include_programs boolean DEFAULT NULL,
	p_include_faculties boolean DEFAULT NULL,
	p_include_address boolean DEFAULT NULL

) RETURNS TABLE (
    insert_timestamp       timestamp with time zone,
    id                     uuid,
    author_id              uuid,
    created                timestamp with time zone,
    modified               timestamp with time zone,
    archived               boolean,
    deleted                boolean,
    slug                   char(9),
    name                   text,
    description            text,
    start_time             timestamp with time zone,
    end_time               timestamp with time zone,
    latitude               numeric(8, 6),
    longitude              numeric(9, 6),
    logo_id                uuid,
    logo_url               text,
    url                    text,
    product_id             integer,
    external_id            varchar(100),
    mutual_benefit         boolean,
    reciprocity            boolean,
    scholarship            boolean,
    teaching               boolean,
    scholarly_research     boolean,
    student_participation  boolean,
    student_members        integer,
    student_members_actual boolean,
    student_hours          integer,
    faculty_participation  boolean,
    faculty_members        integer,
    reflections            boolean,
    reflection_description text,
    frequency              integer,
    contact_phone_public   boolean,
    contact_email_public   boolean,
    irb_protocol           boolean,
    irb_protocol_id        text,
    individuals_served     integer,
    community_insight      text,
    goals_feedback         text,
    focuses                text[],
    focus_areas            jsonb,
    populations            text[],
    organizing_framework   text[],
    events_services        text[],
    scholarship_types      text[],
    expected_scholarly_outputs text[],
    achieved_scholarly_outputs text[],
    expected_ps_outputs    text[],
    achieved_ps_outputs    text[],
    expected_outcomes      text[],
    achieved_outcomes      text[],
    expected_impacts       text[],
    achieved_impacts       text[],
    research_types         text[],
    external_partners      boolean,
    student_hours_actual   boolean,
    modified_by            uuid,
    status                 text,
    contact_firstname      text,
    contact_lastname       text,
    contact_email          text,
    contact_office         text,
    contact_phone          text,
    contact_private_email  boolean,
    contact_private_name   boolean,
    primary_activity       text,
    type                   text,
    featured               timestamp with time zone,
    contact_private_phone  boolean,
    portal_id              uuid,
    activity_lead          uuid,
    activity_lead_status   text,
    distance               float,
    funders                text,
    communities            text,
    units                  text,
    programs               text,
    faculties              text,
    address                text         
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT act.*, ids.distance,
                    CASE WHEN p_include_funders THEN (SELECT community_funders::text FROM collab.getFundersActivityFunc(fund.activity_id::varchar)) END AS funders,
                    CASE WHEN p_include_communities THEN (SELECT communities::text FROM collab.getActivityCommunityOrgFunc(fund.activity_id::varchar)) END AS communities,
                    CASE WHEN p_include_units THEN (SELECT units FROM collab.getActivityUnitsFunc(fund.activity_id::varchar)) END AS units,
                    CASE WHEN p_include_programs THEN (SELECT programs FROM collab.getActivityProgramsFunc(fund.activity_id::varchar)) END AS programs,
                    CASE WHEN p_include_faculties THEN (SELECT faculty FROM collab.getActivityFacultyStaffFunc(fund.activity_id::varchar)) END AS faculties,
                    CASE WHEN p_include_address THEN (SELECT address::text FROM collab.getActivityAddressFunc(fund.activity_id::varchar)) END AS address
                    FROM collab.v_activity_funders fund
                    INNER JOIN (SELECT ret_id, distance
                                    FROM collab.GetActivityIDsFunc(
                                        p_portal_id,
                                        p_status,
                                        p_start_time,
                                        p_end_time,
                                        p_focus_areas,
                                        p_program_id,
                                        p_unit_id,
                                        p_longitude,
                                        p_latitude,
                                        p_distance,
                                        p_virtual_location,
                                        p_type)
                                ) ids
                                ON fund.activity_id = ids.ret_id
                    INNER JOIN collab.v_activities AS act ON act.id = ids.ret_id
                    WHERE (p_funder_id IS NULL OR fund.funder_id = p_funder_id::uuid)
                    ORDER BY
                        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN act.name END ASC,
                        CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN act.name END DESC,
                        CASE WHEN p_sort_by = 'created' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN act.created END ASC,
                        CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN act.created END DESC,
                        CASE WHEN p_sort_by IS NULL THEN act.created END ASC                  
                    LIMIT p_limit
                    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getactivityfundersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_funder_id varchar,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean,
	p_include_address boolean
) TO api_readonly;


COMMENT ON FUNCTION collab.getactivityfundersActivitiesfunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_funder_id varchar,
	p_include_funders boolean,
	p_include_communities boolean,
	p_include_units boolean,
	p_include_programs boolean,
	p_include_faculties boolean,
	p_include_address boolean
) IS E'@name getactivityfundersActivitiesfunc';

-------------- collab.getFacultyPartnersTotalFunc ----------------------------
drop function if exists collab.getFacultyPartnersTotalFunc;

CREATE OR REPLACE FUNCTION collab.getFacultyPartnersTotalFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL
)
RETURNS integer
AS $$
# variable_conflict use_column
DECLARE
    ret_count integer;
BEGIN
    SELECT SUM(collab.v_activities.faculty_members)::integer
    INTO ret_count
    FROM collab.v_activities
    WHERE id IN (SELECT ret_id
        FROM collab.GetActivityIDsFunc(
            p_portal_id,
            p_status,
            p_start_time,
            p_end_time,
            p_focus_areas,
            p_program_id,
            p_unit_id,
            p_longitude,
            p_latitude,
            p_distance,
            p_virtual_location,
            p_type
        )
    );

    RETURN ret_count;
END;
$$ LANGUAGE plpgsql;


GRANT EXECUTE ON FUNCTION collab.getFacultyPartnersTotalFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getFacultyPartnersTotalFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar
) IS E'@name getFacultyPartnersTotalFunc';

----------------------- Activity Addresses
 
drop function if exists collab.getActivityAddressFunc;
CREATE OR REPLACE FUNCTION collab.getActivityAddressFunc(
    p_activity_id varchar

) RETURNS TABLE (
    address text    
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT
                    jsonb_agg(
                        jsonb_build_object(
                            'country', country,
                            'street', street,
                            'street2', street2,
                            'postal', postal,
                            'county', county,
                            'city', city,
                            'state', state,
                            'virtual', virtual
                        )
                    )::text AS address
                FROM collab.v_activity_sites
                WHERE activity_id = p_activity_id::uuid;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getActivityAddressFunc(
    p_activity_id varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getActivityAddressFunc(
    p_activity_id varchar
) IS E'@name getActivityAddressFunc';

----------------------- Activity Units
 
drop function if exists collab.getActivityUnitsFunc;
CREATE OR REPLACE FUNCTION collab.getActivityUnitsFunc(
    p_activity_id varchar

) RETURNS TABLE (
    units text     
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT STRING_AGG(name, ',')::text AS names
                 FROM (SELECT u.name
                    FROM collab.v_units u
                    INNER JOIN collab.v_activity_to_units au ON u.id = au.unit_id
                    WHERE au.activity_id = p_activity_id::uuid
                    ORDER BY u.name) AS tbl;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getActivityUnitsFunc(
    p_activity_id varchar
) TO api_readonly;

----------------------- Activity Programs
 
drop function if exists collab.getActivityProgramsFunc;
CREATE OR REPLACE FUNCTION collab.getActivityProgramsFunc(
    p_activity_id varchar

) RETURNS TABLE (
    programs text     
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT STRING_AGG(name, ',')::text AS names
                 FROM (SELECT p.name
                        FROM collab.v_activity_to_programs AS ap
                        INNER JOIN collab.v_programs_initiatives AS p ON p.id = ap.program_id
                        WHERE ap.activity_id = p_activity_id::uuid
                        ORDER BY p.name) AS tbl;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getActivityProgramsFunc(
    p_activity_id varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getActivityProgramsFunc(
    p_activity_id varchar
) IS E'@name getActivityProgramsFunc';

----------------------- Activity Faculty/Staff
 
drop function if exists collab.getActivityFacultyStaffFunc;
CREATE OR REPLACE FUNCTION collab.getActivityFacultyStaffFunc(
    p_activity_id varchar

) RETURNS TABLE (
    faculty text     
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT STRING_AGG(name, ',')::text AS names
                 FROM (SELECT DISTINCT ON (u.id) (u.firstname || ' ' || u.lastname) AS name
                        FROM users.users u
                        INNER JOIN users.user_emails em ON u.id = em.user_id
                        INNER JOIN users.user_associations ua ON u.id = ua.user_id
                        WHERE ua.entity_id = p_activity_id::uuid
                        ORDER BY u.id, u.firstname, u.lastname) AS tbl;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getActivityFacultyStaffFunc(
    p_activity_id varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getActivityFacultyStaffFunc(
    p_activity_id varchar
) IS E'@name getActivityFacultyStaffFunc';

----------------------- Activity Community Organizations
 
drop function if exists collab.getActivityCommunityOrgFunc;
CREATE OR REPLACE FUNCTION collab.getActivityCommunityOrgFunc(
    p_activity_id varchar

) RETURNS TABLE (communities text) AS $$
BEGIN
    RETURN QUERY SELECT
        jsonb_agg(
            jsonb_build_object(
                'organization_name', o.name,
                'contact_name', cp.contact_firstname || ' ' || cp.contact_lastname,
                'contact_email', cp.contact_email,
                'community_partner_roles', cp.community_partner_roles
            )
        )::text
        FROM collab.v_activity_to_community_partners AS cp
        INNER JOIN collab.v_organizations AS o ON o.id = cp.community_id
        WHERE cp.activity_id = p_activity_id::uuid;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getActivityCommunityOrgFunc(
    p_activity_id varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getActivityCommunityOrgFunc(
    p_activity_id varchar
) IS E'@name getActivityCommunityOrgFunc';

----------------------- Activity Community Organization Contact
 
drop function if exists collab.getActivityCommunityOrgContactFunc;

----------------------- Activity Community Organization Roles
 
drop function if exists collab.getActivityCommunityOrgRolesFunc;


----------------------- Activity Funders
 
drop function if exists collab.getFundersActivityFunc;
CREATE OR REPLACE FUNCTION collab.getFundersActivityFunc(
    p_activity_id varchar

) RETURNS TABLE (
    community_funders text     
) AS $$
#variable_conflict use_column
BEGIN
  RETURN QUERY
        SELECT
            jsonb_agg (
                jsonb_build_object (
                    'name', NAME,
                    'source', SOURCE,
                    'amount', amount,
                    'dates', (start_ts || ' - ' || end_ts)::text
                )
            ) :: text
        FROM collab.v_activity_funders
        WHERE activity_id = p_activity_id ::uuid;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getFundersActivityFunc(
    p_activity_id varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getFundersActivityFunc(
    p_activity_id varchar
) IS E'@name getFundersActivityFunc';

----------------------- Activity Courses
 
drop function if exists collab.getActivityCoursesFunc;
CREATE OR REPLACE FUNCTION collab.getActivityCoursesFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_activity_id varchar DEFAULT NULL

) RETURNS TABLE (
    activity_id varchar,
    activity_name text,
    activity_created timestamp with time zone,
    courses text     
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT * 
                FROM (SELECT id::varchar, name, created, courses
                        FROM (
                            SELECT act.id, act.name, act.created, STRING_AGG(c.name, ',') AS courses
                            FROM collab.v_activities AS act
                            INNER JOIN (SELECT ret_id, distance
                                        FROM collab.GetActivityIDsFunc(
                                            p_portal_id,
                                            p_status,
                                            p_start_time,
                                            p_end_time,
                                            p_focus_areas,
                                            p_program_id,
                                            p_unit_id,
                                            p_longitude,
                                            p_latitude,
                                            p_distance,
                                            p_virtual_location,
                                            p_type)
                                    ) ids
                            ON act.id = ids.ret_id
                            INNER JOIN collab.v_activity_to_sections AS ats
                            ON ats.activity_id = act.id
                            INNER JOIN collab.v_sections AS s 
                                ON s.id = ats.section_id
                            INNER JOIN collab.v_courses AS c 
                                ON c.id = s.course_id
                            WHERE (p_activity_id IS NULL OR act.id = p_activity_id::uuid)
                            GROUP BY act.id, act.name, act.created
                        ) AS pedagogies
                    ) AS tbl
                    ORDER BY
                        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN name END ASC,
                        CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN name END DESC,
                        CASE WHEN p_sort_by = 'created' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN created END ASC,
                        CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN created END DESC,
                        CASE WHEN p_sort_by IS NULL THEN created END ASC                  
                    LIMIT p_limit
                    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getActivityCoursesFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_activity_id varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getActivityCoursesFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_activity_id varchar
) IS E'@name getActivityCoursesFunc';

----------------------- Activity Pedagogies
 
drop function if exists collab.getActivityPedagogiesFunc;
CREATE OR REPLACE FUNCTION collab.getActivityPedagogiesFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_activity_id varchar DEFAULT NULL

) RETURNS TABLE (
    activity_id varchar,
    activity_name text,
    activity_created timestamp with time zone,
    pedagogies text     
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT * 
                FROM (SELECT id::varchar, name, created, STRING_AGG(pedagogy, ',')
                        FROM (
                            SELECT act.id, act.name, act.created, unnest(ats.pedagogies) AS pedagogy
                            FROM collab.v_activities AS act
                            INNER JOIN (SELECT ret_id, distance
                                        FROM collab.GetActivityIDsFunc(
                                            p_portal_id,
                                            p_status,
                                            p_start_time,
                                            p_end_time,
                                            p_focus_areas,
                                            p_program_id,
                                            p_unit_id,
                                            p_longitude,
                                            p_latitude,
                                            p_distance,
                                            p_virtual_location,
                                            p_type)
                                    ) ids
                            ON act.id = ids.ret_id
                            INNER JOIN collab.v_activity_to_sections AS ats
                            ON ats.activity_id = act.id
                            INNER JOIN collab.v_sections AS s ON s.id = ats.section_id
                            WHERE (p_activity_id IS NULL OR act.id = p_activity_id::uuid)
                        ) AS pedagogies
                        GROUP BY id, name, created) AS tbl
                    ORDER BY
                        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN name END ASC,
                        CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN name END DESC,
                        CASE WHEN p_sort_by = 'created' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN created END ASC,
                        CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN created END DESC,
                        CASE WHEN p_sort_by IS NULL THEN created END ASC                  
                    LIMIT p_limit
                    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getActivityPedagogiesFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_activity_id varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getActivityPedagogiesFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_activity_id varchar
) IS E'@name getActivityPedagogiesFunc';

----------------------- Activity Learnig Objectives
 
drop function if exists collab.getActivityLearnigObjectivesFunc;
CREATE OR REPLACE FUNCTION collab.getActivityLearnigObjectivesFunc(
    p_portal_id varchar,
    p_sort_by varchar DEFAULT 'name',
    p_sort_dir varchar DEFAULT 'ASC',
    p_limit integer DEFAULT 100,
    p_offset integer DEFAULT 0,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_unit_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL,
    p_type varchar DEFAULT NULL,
    p_activity_id varchar DEFAULT NULL

) RETURNS TABLE (
    activity_id varchar,
    activity_name text,
    activity_created timestamp with time zone,
    learning_objectives text     
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT * 
                FROM (SELECT id::varchar, name, created, STRING_AGG(pedagogy, ',')
                        FROM (
                            SELECT act.id, act.name, act.created, unnest(ats.pedagogies) AS pedagogy
                            FROM collab.v_activities AS act
                            INNER JOIN (SELECT ret_id, distance
                                        FROM collab.GetActivityIDsFunc(
                                            p_portal_id,
                                            p_status,
                                            p_start_time,
                                            p_end_time,
                                            p_focus_areas,
                                            p_program_id,
                                            p_unit_id,
                                            p_longitude,
                                            p_latitude,
                                            p_distance,
                                            p_virtual_location,
                                            p_type)
                                    ) ids
                            ON act.id = ids.ret_id
                            INNER JOIN collab.v_activity_to_sections AS ats ON ats.activity_id = act.id
                            INNER JOIN collab.v_sections AS s ON s.id = ats.section_id
                            WHERE (p_activity_id IS NULL OR act.id = p_activity_id::uuid)
                        ) AS pedagogies
                        GROUP BY id, name, created) AS tbl
                    ORDER BY
                        CASE WHEN p_sort_by = 'name' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN name END ASC,
                        CASE WHEN p_sort_by = 'name' AND upper(p_sort_dir) = 'DESC' THEN name END DESC,
                        CASE WHEN p_sort_by = 'created' AND (upper(p_sort_dir) = 'ASC' OR p_sort_dir IS NULL) THEN created END ASC,
                        CASE WHEN p_sort_by = 'created' AND upper(p_sort_dir) = 'DESC' THEN created END DESC,
                        CASE WHEN p_sort_by IS NULL THEN created END ASC                  
                    LIMIT p_limit
                    OFFSET p_offset;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION collab.getActivityLearnigObjectivesFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_activity_id varchar
) TO api_readonly;


COMMENT ON FUNCTION collab.getActivityLearnigObjectivesFunc(
    p_portal_id varchar,
    p_sort_by varchar,
    p_sort_dir varchar,
    p_limit integer,
    p_offset integer,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_unit_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean,
    p_type varchar,
    p_activity_id varchar
) IS E'@name getActivityLearnigObjectivesFunc';

--end