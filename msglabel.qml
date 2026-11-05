import bb.cascades 1.2

// 单条消息：助手是满宽纯文字，用户是右对齐气泡
Container {
    id: item
    property string text: ""
    property bool mine: false

    horizontalAlignment: HorizontalAlignment.Fill
    layout: DockLayout {}

    topPadding: 6
    bottomPadding: 6
    leftPadding: 10
    rightPadding: 10

    Container {
        horizontalAlignment: item.mine ? HorizontalAlignment.Right : HorizontalAlignment.Fill
        maxWidth: item.mine ? 500 : 700

        background: item.mine ? Color.create("#3a6ea5") : Color.create("#00000000")
        layout: StackLayout {}

        topPadding: item.mine ? 12 : 4
        bottomPadding: item.mine ? 12 : 4
        leftPadding: item.mine ? 14 : 0
        rightPadding: item.mine ? 14 : 0

        Label {
            text: item.text
            multiline: true
            textStyle {
                color: item.mine ? Color.create("#eaf2f8") : Color.create("#e8e8ea")
                fontSize: FontSize.Small
            }
        }
    }
}
