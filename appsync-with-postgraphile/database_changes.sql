-------------- collab.GetActivityIDsFunc ----------------------------

drop function if exists collab.GetActivityIDsFunc;

CREATE OR REPLACE FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL
)
RETURNS TABLE (ret_id uuid, distance double precision)
AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT collab.activities.id, ST_DistanceSphere(ST_MakePoint(longitude, latitude), ST_MakePoint(p_longitude, p_latitude)) * 0.000621371 as distance
                 FROM collab.activities
                 WHERE portal_id = p_portal_id::uuid
                   AND (p_status IS NULL OR status = p_status)
                   AND (p_start_time IS NULL OR start_time > p_start_time - interval '1 second')
                   AND (p_end_time IS NULL OR start_time < p_end_time + interval '1 second')
                   AND (p_focus_areas IS NULL OR focus_areas @> p_focus_areas)
                   AND (p_program_id IS NULL OR id IN (SELECT activity_id FROM collab.activity_to_programs WHERE program_id = ANY (CAST(p_program_id AS uuid[]))))
                   AND (
                       p_longitude IS NULL AND p_latitude IS NULL
                       OR (
                           (p_virtual_location = true AND (NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id) OR EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)))
                           OR (p_virtual_location = false AND NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true) AND ST_DistanceSphere(ST_MakePoint(longitude, latitude), ST_MakePoint(p_longitude, p_latitude)) * 0.000621371 < p_distance)
                       )
                   )
                   AND (p_virtual_location IS NULL OR (p_virtual_location = true AND EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)) OR (p_virtual_location = false AND NOT EXISTS(SELECT 1 FROM collab.activity_sites WHERE activity_id = collab.activities.id AND virtual = true)));
END;
$$ LANGUAGE plpgsql;

comment on function collab.GetActivityIDsFunc(varchar, text, timestamp, timestamp, jsonb, character varying[], double precision, double precision, double precision, boolean) is '@omit: "create,update,delete"';

-------------- collab.GetActivityCountFunc ----------------------------
drop function if exists collab.GetActivityCountFunc;

CREATE OR REPLACE FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL
)
RETURNS TABLE (portalid varchar, count bigint)
AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY SELECT portal_id::varchar, count(id)
                 FROM collab.activities
                 WHERE id IN (SELECT ret_id FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id, p_longitude, p_latitude, p_distance, p_virtual_location))
                 GROUP BY portal_id;
END;
$$ LANGUAGE plpgsql;



GRANT EXECUTE ON FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
) TO api_readonly;

GRANT EXECUTE ON FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
) TO api_readonly;

COMMENT ON FUNCTION collab.GetActivityCountFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
) IS E'@name GetActivityCountFunc';

COMMENT ON FUNCTION collab.GetActivityIDsFunc(
    p_portal_id varchar,
    p_status text ,
    p_start_time timestamp ,
    p_end_time timestamp ,
    p_focus_areas jsonb ,
    p_program_id varchar[] ,
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
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
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL
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
    distance               float
) AS $$
#variable_conflict use_column
BEGIN
    RETURN QUERY
    SELECT collab.activities.*,ids.distance
    FROM collab.activities inner join
       (SELECT ret_id,distance FROM collab.GetActivityIDsFunc(p_portal_id, p_status, p_start_time, p_end_time, p_focus_areas, p_program_id, p_longitude, p_latitude, p_distance, p_virtual_location)) ids
                      on collab.activities.id=ids.ret_id
    ORDER BY CASE WHEN p_sort_dir = 'DESC' THEN $1 END DESC,
             CASE WHEN p_sort_dir = 'ASC' THEN $1 END ASC
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
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
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
    p_longitude double precision ,
    p_latitude double precision ,
    p_distance double precision ,
    p_virtual_location boolean
) IS E'@name GetActivitiesFunc';


----------------------------   GetFacStaffCountFunc -----------------------------

CREATE OR REPLACE FUNCTION collab.GetFacStaffCountFunc(
    p_portal_id varchar,
    p_status text DEFAULT NULL,
    p_start_time timestamp DEFAULT NULL,
    p_end_time timestamp DEFAULT NULL,
    p_focus_areas jsonb DEFAULT NULL,
    p_program_id varchar[] DEFAULT NULL::varchar[],
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL
)
RETURNS integer
AS $$
DECLARE
    ret_count integer;
BEGIN
    SELECT count(distinct u.id)
    INTO ret_count
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
                p_longitude,
                p_latitude,
                p_distance,
                p_virtual_location
            )
        ) ids ON ua.entity_id = ids.ret_id AND type <> 'proxy';

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
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean
) TO api_readonly;


COMMENT ON FUNCTION collab.GetFacStaffCountFunc(
    p_portal_id varchar,
    p_status text,
    p_start_time timestamp,
    p_end_time timestamp,
    p_focus_areas jsonb,
    p_program_id varchar[],
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean
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
    p_longitude double precision DEFAULT NULL,
    p_latitude double precision DEFAULT NULL,
    p_distance double precision DEFAULT NULL,
    p_virtual_location boolean DEFAULT NULL
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
    RETURN QUERY SELECT u.id::text, u.firstname, u.lastname, em.email
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
                                  p_longitude,
                                  p_latitude,
                                  p_distance,
                                  p_virtual_location
                              )
                          ) ids ON ua.entity_id = ids.ret_id AND type <> 'proxy'
                 group by u.id, u.firstname, u.lastname, em.email
                 ORDER BY
                     CASE WHEN p_sort_by = 'firstname' AND upper(p_sort_dir)  = 'ASC' THEN (u.firstname,u.lastname) END ASC,
                     CASE WHEN p_sort_by = 'firstname' AND upper(p_sort_dir) = 'DESC' THEN (u.firstname,u.lastname) END DESC,
                     CASE WHEN p_sort_by = 'lastname' AND upper(p_sort_dir) = 'ASC' THEN (u.lastname,u.firstname) END ASC,
                     CASE WHEN p_sort_by = 'lastname' AND upper(p_sort_dir) = 'DESC' THEN (u.lastname,u.firstname) END DESC,
                     u.id ASC
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
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean
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
    p_longitude double precision,
    p_latitude double precision,
    p_distance double precision,
    p_virtual_location boolean
)  IS E'@name GetFacStaffFunc';