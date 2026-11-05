TEMPLATE = app
TARGET = deepseek
CONFIG += qt warn_on release cascades
INCLUDEPATH += src
SOURCES += src/main.cpp
RESOURCES += resources.qrc

device {
    CONFIG(release, debug|release) {
        DESTDIR = arm/o.le-v7
        OBJECTS_DIR = arm/o.le-v7/.obj
        MOC_DIR = arm/o.le-v7/.moc
    }
}
