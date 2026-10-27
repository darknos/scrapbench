import Foundation

extension CodeGrammar {
    static let sql = CodeGrammar(aliases: ["sql", "mysql", "postgres", "postgresql", "psql", "sqlite"], rules: [
        Rule(#"--[^\n]*"#, .comment),
        .blockComment,
        .singleQuoted,
        .keywords("""
            select from where and or not in is null as join left right inner outer full on group by order \
            having limit offset insert into values update set delete create table index view drop alter add \
            column primary key foreign references unique default distinct union all exists between like \
            case when then else end asc desc with returning truncate begin commit rollback explain analyze \
            cast coalesce count sum avg min max int integer bigint text varchar boolean timestamp date \
            true false
            """, caseInsensitive: true),
        .number,
    ])
}
