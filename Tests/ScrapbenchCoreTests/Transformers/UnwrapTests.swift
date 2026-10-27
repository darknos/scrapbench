import Testing
@testable import ScrapbenchCore

@Suite struct UnwrapTests {
    let t = UnwrapTransformer()

    let terminal = """
    Все 12 задач плана выполнены и закоммичены на ветке feat/transformers (13 коммитов), Calculate вынесен в группу Math. Тесты
      118/118. Запустил свежее ревью всей ветки отдельным агентом.

      Пока оно идёт, коротко что получилось:

      - ⌘K открывает палитру над выделением или текущим scrap, показывает только применимые трансформеры с fuzzy-поиском, Enter
        применяет одним undo-шагом, Esc или потеря фокуса закрывает.
      - ⌘⇧K повторяет последний трансформер без палитры.

      Замечание по ходу тестов: пока я гонял палитру, кто-то нажимал клавиши и мышь в моих тестовых окнах (в scratch-файл попали "mu",
      палитра закрывалась по Esc).

    """

    @Test func joinsWrappedTerminalOutputKeepingParagraphsAndBullets() throws {
        #expect(try t.apply(terminal) == """
        Все 12 задач плана выполнены и закоммичены на ветке feat/transformers (13 коммитов), Calculate вынесен в группу Math. Тесты 118/118. Запустил свежее ревью всей ветки отдельным агентом.

        Пока оно идёт, коротко что получилось:

        - ⌘K открывает палитру над выделением или текущим scrap, показывает только применимые трансформеры с fuzzy-поиском, Enter применяет одним undo-шагом, Esc или потеря фокуса закрывает.
        - ⌘⇧K повторяет последний трансформер без палитры.

        Замечание по ходу тестов: пока я гонял палитру, кто-то нажимал клавиши и мышь в моих тестовых окнах (в scratch-файл попали "mu", палитра закрывалась по Esc).

        """)
    }

    @Test func blockStartsAreNotJoinedToThePreviousLine() throws {
        #expect(try t.apply("# Title\ntext one\ntext two\n> quoted\n| a | b |\n1. first\n   more\n2. second") ==
            "# Title\ntext one text two\n> quoted\n| a | b |\n1. first more\n2. second")
    }

    @Test func fencedCodeIsKeptVerbatim() throws {
        let text = "intro\n  line\n```sh\n  make app \\\n    SIGN=x\n```\nafter\n  text"
        #expect(try t.apply(text) == "intro line\n```sh\n  make app \\\n    SIGN=x\n```\nafter text")
    }

    @Test func collapsesRepeatedBlankLinesToOne() throws {
        #expect(try t.apply("a\nb\n\n\n\nc") == "a b\n\nc")
    }

    @Test func applicability() {
        #expect(t.canApply(to: "wrapped\n  continuation"))
        #expect(!t.canApply(to: "single line"))
        #expect(!t.canApply(to: "- one\n- two"))
        #expect(!t.canApply(to: "para\n\npara"))
        #expect(t.id == "lines.unwrap")
        #expect(t.name == "Unwrap lines")
        #expect(t.group == .lines)
    }
}
