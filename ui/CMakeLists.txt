cmake_minimum_required(VERSION 3.22)
project(omni-shell-prototipo LANGUAGES CXX)
# OMNI Shell — prototipo anticipato dell'interfaccia (non M4). Qt 6 / QML.
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Quick Test QuickTest DBus)

add_library(omni_desktopentries STATIC src/desktopentries.cpp src/desktopentries.h src/applauncher.cpp src/applauncher.h)
target_link_libraries(omni_desktopentries PUBLIC Qt6::Core)
target_include_directories(omni_desktopentries PUBLIC src)

add_executable(omni-shell-prototipo src/main.cpp src/recorder.cpp src/recorder.h
    src/notificationserver.cpp src/notificationserver.h src/sessionactions.cpp src/sessionactions.h
    src/systemstatus.cpp src/systemstatus.h src/shellservices.cpp src/shellservices.h)
target_link_libraries(omni-shell-prototipo PRIVATE omni_desktopentries Qt6::Gui Qt6::Quick Qt6::DBus)
target_compile_definitions(omni-shell-prototipo PRIVATE OMNI_QML_DIR="${CMAKE_CURRENT_SOURCE_DIR}/qml")
target_compile_options(omni-shell-prototipo PRIVATE -Wall -Wextra)

enable_testing()
add_executable(tst_desktopentries tests/tst_desktopentries.cpp)
target_link_libraries(tst_desktopentries PRIVATE omni_desktopentries Qt6::Test)
add_test(NAME desktopentries COMMAND tst_desktopentries)
add_executable(tst_applauncher tests/tst_applauncher.cpp)
target_link_libraries(tst_applauncher PRIVATE omni_desktopentries Qt6::Test)
add_test(NAME applauncher COMMAND tst_applauncher)

add_executable(tst_desktop tests/tst_desktop.cpp src/notificationserver.cpp src/sessionactions.cpp src/systemstatus.cpp src/shellservices.cpp)
target_link_libraries(tst_desktop PRIVATE omni_desktopentries Qt6::Quick Qt6::QuickTest Qt6::DBus)
target_compile_definitions(tst_desktop PRIVATE QUICK_TEST_SOURCE_DIR="${CMAKE_CURRENT_SOURCE_DIR}/tests_desktop"
    OMNI_TEST_APPS="${CMAKE_CURRENT_SOURCE_DIR}/tests/desktop")
add_test(NAME desktop COMMAND tst_desktop -import ${CMAKE_CURRENT_SOURCE_DIR}/qml)

add_executable(tst_notifications tests/tst_notifications.cpp src/notificationserver.cpp)
target_link_libraries(tst_notifications PRIVATE Qt6::Test Qt6::DBus)
target_include_directories(tst_notifications PRIVATE src)
find_program(DBUS_RUN_SESSION dbus-run-session)
if(DBUS_RUN_SESSION)
    add_test(NAME notifications COMMAND ${DBUS_RUN_SESSION} -- $<TARGET_FILE:tst_notifications>)
endif()

find_program(QMLTESTRUNNER qmltestrunner HINTS /usr/lib/qt6/bin /usr/lib64/qt6/bin /usr/lib/x86_64-linux-gnu/qt6/bin)
add_test(NAME qml COMMAND ${QMLTESTRUNNER} -import ${CMAKE_CURRENT_SOURCE_DIR}/qml -input ${CMAKE_CURRENT_SOURCE_DIR}/tests)
set_tests_properties(qml desktopentries applauncher desktop PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
add_test(NAME cablaggio_avvio_reale COMMAND bash ${CMAKE_CURRENT_SOURCE_DIR}/tests/cablaggio_avvio_reale.sh $<TARGET_FILE:omni-shell-prototipo> ${CMAKE_CURRENT_SOURCE_DIR}/qml)
# Nessuna funzione di intelligenza artificiale nell'interfaccia (richiesta per questa fase)
add_test(NAME nessuna_ai COMMAND bash -c "! grep -rniE 'assistente|intelligenza artificiale|qsTr\\(\"AI' ${CMAKE_CURRENT_SOURCE_DIR}/qml/OmniDesktop ${CMAKE_CURRENT_SOURCE_DIR}/qml/DesktopSession.qml ${CMAKE_CURRENT_SOURCE_DIR}/qml/OmniShell/QuickSettings.qml ${CMAKE_CURRENT_SOURCE_DIR}/qml/OmniShell/TopBar.qml")
