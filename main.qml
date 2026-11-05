import bb.cascades 1.2

Page {
    id: root
    property string apiKey: Store.get("apiKey")
    property variant history: []
    property bool busy: false
    property variant lastItem: null
    property variant msgComponent: null

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

        ScrollView {
            id: scroller
            horizontalAlignment: HorizontalAlignment.Fill
            verticalAlignment: VerticalAlignment.Fill

            Container {
                id: feed
                layout: StackLayout {}
                horizontalAlignment: HorizontalAlignment.Fill
                bottomPadding: 108
            }
        }

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
                    preferredHeight: 76
                    maxHeight: 76
                }

                Button {
                    text: root.busy ? "…" : "发送"
                    verticalAlignment: VerticalAlignment.Bottom
                    preferredWidth: 100
                    preferredHeight: 76
                    enabled: !root.busy
                    onClicked: root.send()
                }
            }
        }
    }

    attachedObjects: [
        Sheet {
            id: settings
            content: Page {
                titleBar: TitleBar {
                    title: "设置"
                    dismissAction: ActionItem {
                        title: "关闭"
                        onTriggered: settings.close()
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
                        hintText: "sk-..."
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

    function scrollToEnd() {
        try {
            scroller.scrollToPoint(0, 100000);
        } catch (e) {
            // 该版本不支持滚动 API 时静默跳过
        }
    }

    function cleanMarkdown(t) {
        var out = "" + t;
        out = out.replace(/```[a-zA-Z]*\n?/g, "");
        out = out.replace(/\*\*([^*\n]+)\*\*/g, "$1");
        out = out.replace(/__([^_\n]+)__/g, "$1");
        out = out.replace(/`([^`\n]+)`/g, "$1");
        out = out.replace(/^#{1,6}\s*/gm, "");
        out = out.replace(/^\s*[-*]\s+/gm, "• ");
        out = out.replace(/^\s*\d+\.\s+/gm, "");
        return out;
    }

    function historyJson() {
        var parts = [];
        for (var i = 0; i < history.length; ++i) {
            parts.push('{"role":"' + history[i].role + '","content":'
                + JSON.stringify(history[i].content) + '}');
        }
        return "[" + parts.join(",") + "]";
    }

    function addMessage(text, mine) {
        if (!root.msgComponent) {
            root.msgComponent = Qt.createComponent("qrc:/msglabel.qml");
        }
        if (!root.msgComponent) {
            return null;
        }
        var obj = root.msgComponent.createObject(feed, { "text": text, "mine": mine });
        if (obj) {
            feed.add(obj);
            root.lastItem = obj;
            scrollToEnd();
        }
        return obj;
    }

    function updateLast(text) {
        if (root.lastItem) {
            root.lastItem.text = text;
            scrollToEnd();
        }
    }

    function handleAnswer(body) {
        root.busy = false;
        try {
            var r = JSON.parse(body);
            if (r.choices && r.choices.length > 0) {
                var answer = cleanMarkdown(r.choices[0].message.content);
                updateLast(answer);
                root.history = root.history.concat([{ role: "assistant", content: answer }]);
            } else {
                updateLast("返回格式异常：" + ("" + body).substring(0, 100));
            }
        } catch (e) {
            updateLast("解析失败：" + e);
        }
    }

    function handleError(err) {
        root.busy = false;
        updateLast("网络错误：" + err);
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
