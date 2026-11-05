#include <bb/cascades/Application>
#include <bb/cascades/QmlDocument>
#include <bb/cascades/AbstractPane>

#include <QSettings>
#include <QString>
#include <QObject>
#include <QDebug>
#include <QSslConfiguration>
#include <QSslCertificate>
#include <QDeclarativeEngine>
#include <QDeclarativeNetworkAccessManagerFactory>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QVariant>
#include <QSslError>
#include <cstdio>

using namespace bb::cascades;

static void msgHandler(QtMsgType, const char *msg)
{
    FILE *f = fopen("/accounts/1000/shared/documents/deepseek.log", "a");
    if (f) {
        fprintf(f, "%s\n", msg);
        fclose(f);
    }
}

class Store : public QObject
{
    Q_OBJECT

public:
    Q_INVOKABLE QString get(const QString &key) const
    {
        QSettings s("com.donggua.deepseek", "chat");
        return s.value(key).toString();
    }

    Q_INVOKABLE void set(const QString &key, const QString &value)
    {
        QSettings s("com.donggua.deepseek", "chat");
        s.setValue(key, value);
        s.sync();
    }
};

// 记录 SSL 错误，便于定位握手失败原因
class LoggingNam : public QNetworkAccessManager
{
    Q_OBJECT

public:
    LoggingNam(QObject *parent = 0) : QNetworkAccessManager(parent) {}

protected:
    QNetworkReply *createRequest(Operation op, const QNetworkRequest &req, QIODevice *out)
    {
        QNetworkReply *reply = QNetworkAccessManager::createRequest(op, req, out);
        connect(reply, SIGNAL(sslErrors(QList<QSslError>)),
                this, SLOT(onSslErrors(QList<QSslError>)));
        return reply;
    }

private slots:
    void onSslErrors(const QList<QSslError> &errors)
    {
        for (int i = 0; i < errors.size(); ++i) {
            qDebug() << "SSL error:" << errors.at(i).errorString();
        }
    }
};


class Net : public QObject
{
    Q_OBJECT

public:
    Net(QObject *parent = 0) : QObject(parent) {}

    Q_INVOKABLE void ask(const QString &apiKey, const QString &messagesJson)
    {
        QNetworkRequest req(QUrl("https://api.deepseek.com/chat/completions"));
        req.setHeader(QNetworkRequest::ContentTypeHeader, QString("application/json"));
        req.setRawHeader("Authorization", QByteArray("Bearer ") + apiKey.toUtf8());

        QByteArray body = QByteArray("{\"model\":\"deepseek-chat\",\"messages\":")
                + messagesJson.toUtf8()
                + QByteArray(",\"stream\":false,\"max_tokens\":1024}");

        qDebug() << "ASK body bytes:" << body.size();
        QNetworkReply *reply = m_nam.post(req, body);
        connect(reply, SIGNAL(finished()), this, SLOT(onFinished()));
        connect(reply, SIGNAL(sslErrors(QList<QSslError>)),
                this, SLOT(onSslErrors(QList<QSslError>)));
    }

signals:
    void answered(const QVariant &body);
    void failed(const QVariant &error);

private slots:
    void onSslErrors(const QList<QSslError> &errors)
    {
        for (int i = 0; i < errors.size(); ++i) {
            qDebug() << "SSL error:" << errors.at(i).errorString();
        }
    }

    void onFinished()
    {
        QNetworkReply *reply = qobject_cast<QNetworkReply *>(sender());
        if (reply == 0) {
            return;
        }
        if (reply->error() != QNetworkReply::NoError) {
            qDebug() << "NET error:" << (int) reply->error() << reply->errorString();
            emit failed(QVariant(reply->errorString()));
        } else {
            emit answered(QVariant(QString::fromUtf8(reply->readAll())));
        }
        reply->deleteLater();
    }

private:
    QNetworkAccessManager m_nam;
};

class NamFactory : public QDeclarativeNetworkAccessManagerFactory
{
public:
    virtual QNetworkAccessManager *create(QObject *parent)
    {
        return new LoggingNam(parent);
    }
};

Q_DECL_EXPORT int main(int argc, char **argv)
{
    qInstallMsgHandler(msgHandler);

    Application app(argc, argv);

    // 内置 CA 证书：BB10 的系统证书库不是 PEM，Qt 读不到
    QList<QSslCertificate> cas = QSslCertificate::fromPath(":/ca.pem");
    qDebug() << "CA certs loaded:" << cas.size();
    if (!cas.isEmpty()) {
        QSslConfiguration cfg = QSslConfiguration::defaultConfiguration();
        cfg.setCaCertificates(cas);
        QSslConfiguration::setDefaultConfiguration(cfg);
    }

    Store store;
    Net net;
    QmlDocument *qml = QmlDocument::create("qrc:/main.qml").parent(&app);
    qml->setContextProperty("Store", &store);
    qml->setContextProperty("Net", &net);

    AbstractPane *root = qml->createRootObject<AbstractPane>();
    if (root == 0) {
        qDebug() << "createRootObject returned NULL";
    }
    app.setScene(root);

    QObject *rootObject = dynamic_cast<QObject *>(root);
    if (rootObject != 0) {
        QObject::connect(&net, SIGNAL(answered(QVariant)), rootObject, SLOT(handleAnswer(QVariant)));
        QObject::connect(&net, SIGNAL(failed(QVariant)), rootObject, SLOT(handleError(QVariant)));
    }

    return app.exec();
}

#include "main.moc"
