
drop table if exists currently_visiting;

create table currently_visiting (
    currently_visiting_id int unsigned  not null auto_increment,
    page_path             varchar(1000) not null,
    user_id               int(10)       not null,
    arrival_time          datetime      not null,

    -- long enough to hold the text representation of an IPv6 address
    -- or an IPv4 address
    ip_address            varchar(39)   not null,

    -- foreign key (user_id)      references user (user_id),
) engine = innodb;


    primary key (currently_visiting_id)

) engine = innodb;

alter table currently_visiting add index
      index_currently_visiting_page_path (page_path);

alter table currently_visiting add index
      index_currently_visiting_user_id (user_id);


