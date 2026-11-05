import bb.cascades 1.2

Page {
    id: root
    property string apiKey: Store.get("apiKey")
    property variant history: []
    property bool busy: false

    titleBar: TitleBar {
        title: "DeepSeek"
        acceptAction: ActionItem {
            title: "设置"
            onTriggered: settings.open()
        }
    }

    Container {
        layout: DockLayout {}
        background: Color.create("#141416")

        // ---------- 消息列表 ----------
        ScrollView {
            id: scroller
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill
            scrollViewProperties {
                scrollMode: ScrollMode.Vertical
            }

            ListView {
                id: chat
                dataModel: messages
                horizontalAlignment: HorizontalAlignment.Fill

                listItemComponents: [
                    ListItemComponent {
                        type: ""
                        Container {
                            horizontalAlignment: HorizontalAlignment.Fill
                            leftPadding: 10
                            rightPadding: 10
                            topPadding: 5
                            bottomPadding: 5

                            Container {
                                horizontalAlignment: ListItemData.mine ? HorizontalAlignment.Right : HorizontalAlignment.Left
                                maxWidth: 520

                                background: ListItemData.mine ? Color.create("#3a6ea5") : Color.create("#2a2a30")
                                layout: StackLayout {}

                                topPadding: 12
                                bottomPadding: 12
                                leftPadding: 14
                                rightPadding: 14

                                Label {
                                    text: ListItemData.text
                                    multiline: true
                                    textStyle {
                                        color: ListItemData.mine ? Color.create("#eaf2f8") : Color.create("#e4e4e6")
                                        fontSize: FontSize.Small
                                    }
                                }
                            }
                        }
                    }
                ]
            }
        }

        // ---------- 输入区 ----------
        Container {
            verticalAlignment: VerticalAlignment.Bottom
            horizontalAlignment: HorizontalAlignment.Fill
            background: Color.create("#1c1c1e")

            Container {
                layout: StackLayout { orientation: LayoutOrientation.LeftToRight }
                topPadding: 8
                bottomPadding: 8
                leftPadding: 8
                rightPadding: 8

                TextArea {
                    id: input
                    hintText: "输入消息…"
                    input.submitKey: SubmitKey.None
                    input.flags: TextInputFlag.SpellCheckOff
                    layoutProperties: StackLayoutProperties { spaceQuota: 1 }
                    minHeight: 96
                    maxHeight: 240
                }

                Button {
                    text: root.busy ? "…" : "发送"
                    verticalAlignment: VerticalAlignment.Bottom
                    preferredWidth: 96
                    preferredHeight: 72
                    enabled: !root.busy
                    onClicked: root.send()
                }
            }
        }
    }

    // ---------- 设置面板 ----------
    attachedObjects: [
        ArrayDataModel {
            id: messages
        },

        Sheet {
            id: settings
            content: Page {
                titleBar: TitleBar {
                    title: "设置"
                    dismissAction: ActionItem {
                        title: "关闭"
                        onTriggered: {
                            settings.close();
                        }
                    }
                    acceptAction: ActionItem {
                        title: "保存"
                        onTriggered: {
                            root.apiKey = keyField.text.trim();
                            Store.set("apiKey", root.apiKey);
                            settings.close();
                        }
                    }
                }
                Container {
                    topPadding: 20
                    leftPadding: 20
                    rightPadding: 20
                    Label {
                        text: "DeepSeek API Key"
                        textStyle { fontWeight: FontWeight.Bold }
                    }
                    TextField {
                        id: keyField
                        hintText: "sk-... "
                        text: root.apiKey
                        input.flags: TextInputFlag.SpellCheckOff
                    }
                    Label {
                        text: "在 platform.deepseek.com 获取，只保存在本机"
                        multiline: true
                        textStyle {
                            color: Color.create("#8b8b93")
                            fontSize: FontSize.XSmall
                        }
                    }
                }
            }
        }
    ]


    function addMessage(text, mine) {
        var m = { text: text, mine: mine };
        messages.insert(0, m);   // Cascades ListView 头部插入
        return m;
    }

    function updateLast(text) {
        if (messages.size() > 0) {
            messages.replace(0, { text: text, mine: false });
        }
    }

    function handleAnswer(body) {
        root.busy = false;
        try {
            var r = JSON.parse(body);
            if (r.choices && r.choices.length > 0) {
                var answer = r.choices[0].message.content;
                root.updateLast(answer);
                root.history = root.history.concat([{ role: "assistant", content: answer }]);
            } else {
                root.updateLast("返回格式异常：" + ("" + body).substring(0, 100));
            }
        } catch (e) {
            root.updateLast("解析失败：" + e);
        }
    }

    function handleError(err) {
        root.busy = false;
        root.updateLast("网络错误：" + err);
    }

    function historyJson() {
        var parts = [];
        for (var i = 0; i < history.length; ++i) {
            var m = history[i];
            parts.push('{"role":"' + m.role + '","content":' + JSON.stringify(m.content) + '}');
        }
        return "[" + parts.join(",") + "]";
    }

    function send() {
        var text = input.text.trim();
        if (text.length === 0 || busy) {
            return;
        }
        input.text = "";
        addMessage(text, true);
        history = history.concat([{ role: "user", content: text }]);

        if (!root.apiKey) {
            addMessage("请先在「设置」里填 API Key", false);
            return;
        }

        busy = true;
        addMessage("思考中…", false);

        Net.ask(root.apiKey, historyJson());
    }
}
