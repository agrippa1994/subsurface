// SPDX-License-Identifier: GPL-2.0
#ifndef IOSSHARE_H
#define IOSSHARE_H

// onlt Qt headers and data structures allowed here
#include <QString>
#include <QObject>

class IosShare : public QObject {
	Q_OBJECT

public:
	IosShare();
	~IosShare();
	void supportEmail(const QString &firstPath, const QString &secondPath);
	void shareViaEmail(const QString &subject, const QString &recipient, const QString &body, const QString &firstPath, const QString &secondPath);
	void shareWithSharesheet(const QString &filePath);
	void showFilePicker();

signals:
	void fileSelected(const QString &path);
private:
	void *self;
};

#endif /* IOSSHARE_H */
