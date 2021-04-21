/*!
 * \copyright Copyright (c) 2014-2021 Governikus GmbH & Co. KG, Germany
 */

#include "states/StateCheckRefreshAddress.h"

#include "AppSettings.h"
#include "context/AuthContext.h"
#include "Env.h"
#include "paos/retrieve/DidAuthenticateEac1Parser.h"
#include "states/StateBuilder.h"
#include "VolatileSettings.h"

#include "MockNetworkManager.h"
#include "TestFileHelper.h"

#include <QtTest>

using namespace governikus;


class test_StateCheckRefreshAddress
	: public QObject
{
	Q_OBJECT
	QScopedPointer<StateCheckRefreshAddress> mState;
	QScopedPointer<MockNetworkManager> mMockNetworkManager;
	QSharedPointer<AuthContext> mAuthContext;

	private:
		static QSharedPointer<TcToken> createTcToken(const QByteArray& redirectUrl)
		{
			QByteArray begin("<?xml version=\"1.0\"?>"
							 "<TCTokenType>"
							 "  <ServerAddress>https://eid-server.example.de/entrypoint</ServerAddress>"
							 "  <SessionIdentifier>1A2BB129</SessionIdentifier>"
							 "  <RefreshAddress>");
			QByteArray end("</RefreshAddress>"
						   "  <Binding> urn:liberty:paos:2006-08 </Binding>"
						   "  <PathSecurity-Protocol> urn:ietf:rfc:4279 </PathSecurity-Protocol>"
						   "  <PathSecurity-Parameters>"
						   "    <PSK> 4BC1A0B5 </PSK>"
						   "  </PathSecurity-Parameters>"
						   "</TCTokenType>");
			QByteArray data = begin.append(redirectUrl).append(end);
			return QSharedPointer<TcToken>(new TcToken(data));
		}

	private Q_SLOTS:
		void init()
		{
			mMockNetworkManager.reset(new MockNetworkManager());
			Env::set(NetworkManager::staticMetaObject, mMockNetworkManager.data());

			mAuthContext.reset(new AuthContext(nullptr));
			mState.reset(StateBuilder::createState<StateCheckRefreshAddress>(mAuthContext));
			mState->onEntry(nullptr);
		}


		void cleanup()
		{
			mState.reset();
			mAuthContext.reset();
			mMockNetworkManager.reset();
		}


		void runNoTcToken()
		{
			QSignalSpy spyContinue(mState.data(), &StateCheckRefreshAddress::fireContinue);

			QTest::ignoreMessage(QtDebugMsg, "Invalid TCToken");
			mState->run();
			QCOMPARE(spyContinue.count(), 1);
		}


		void run_data()
		{
			QTest::addColumn<QByteArray>("redirectUrl");
			QTest::addColumn<QString>("tcTokenUrl");
			QTest::addColumn<QStringList>("messages");

			const QStringList msg1(QString("Invalid RefreshAddress: test"));
			const QStringList msg2(QString("Invalid RefreshAddress: http://service.governikus.de/loggedin?7eb39f62"));
			const QStringList msg3 = {QString("Subject URL from AT CVC (eService certificate) description: \"https://service.governikus.de\""), QString("Current redirect URL: \"https://service.governikus.de/loggedin?7eb39f62\""), QString("SOP-Check succeeded, abort process.")};
			const QStringList msg4 = {QString("Subject URL from AT CVC (eService certificate) description: \"https://governikus.de\""), QString("Current redirect URL: \"https://service.governikus.de/loggedin?7eb39f62\""), QString("SOP-Check failed, start process.")};

			QTest::newRow("urlInvalid") << QByteArray("test") << QString() << msg1;
			QTest::newRow("notHttps") << QByteArray("http://service.governikus.de/loggedin?7eb39f62") << QString("http://service.governikus.de") << msg2;
			QTest::newRow("matchingSameOriginPolicy") << QByteArray("https://service.governikus.de/loggedin?7eb39f62") << QString("https://service.governikus.de") << msg3;
			QTest::newRow("notMatchingSameOriginPolicy") << QByteArray("https://service.governikus.de/loggedin?7eb39f62") << QString("https://governikus.de") << msg4;
		}


		void run()
		{
			QFETCH(QByteArray, redirectUrl);
			QFETCH(QString, tcTokenUrl);
			QFETCH(QStringList, messages);

			QSignalSpy spyContinue(mState.data(), &StateCheckRefreshAddress::fireContinue);

			const auto& tcToken = createTcToken(redirectUrl);
			const QUrl url(tcTokenUrl);
			QString urlAsString(QString::fromUtf8(redirectUrl));
			QUrl redirectAddress(urlAsString);
			mAuthContext->setTcToken(tcToken);
			mAuthContext->setTcTokenUrl(url);

			for (const auto& msg : messages)
			{
				QTest::ignoreMessage(QtDebugMsg, msg.toLocal8Bit().data());
			}
			mState->run();
			QCOMPARE(mState->mUrl, redirectAddress);
			if (redirectAddress.isValid() && redirectAddress.scheme() == QLatin1String("https"))
			{
				QCOMPARE(mState->mSubjectUrl, url);
			}
			else
			{
				QCOMPARE(spyContinue.count(), 1);
			}
		}


		void mappingToCommunicationError()
		{
			const QVector<GlobalStatus::Code> states = QVector<GlobalStatus::Code>()
					<< GlobalStatus::Code::Network_Ssl_Establishment_Error
					<< GlobalStatus::Code::Network_Ssl_Establishment_Error
					<< GlobalStatus::Code::Workflow_Network_Ssl_Connection_Unsupported_Algorithm_Or_Length
					<< GlobalStatus::Code::Workflow_Network_Ssl_Certificate_Unsupported_Algorithm_Or_Length
					<< GlobalStatus::Code::Workflow_Network_Ssl_Hash_Not_In_Certificate_Description
					<< GlobalStatus::Code::Workflow_Network_Empty_Redirect_Url
					<< GlobalStatus::Code::Workflow_Network_Expected_Redirect
					<< GlobalStatus::Code::Workflow_Network_Invalid_Scheme
					<< GlobalStatus::Code::Workflow_Network_Malformed_Redirect_Url
					<< GlobalStatus::Code::Network_TimeOut
					<< GlobalStatus::Code::Network_Proxy_Error;

			for (const GlobalStatus::Code state : states)
			{
				const ECardApiResult result {GlobalStatus(state)};
				QCOMPARE(result.getMinor(), ECardApiResult::Minor::AL_Communication_Error);
			}
		}


		void sendGetRequestWithoutAnyAdditionalParameters()
		{
			QUrl redirectUrl("http://localhost:12345/test_StateCheckRefreshAddress/");
			mAuthContext->setStatus(GlobalStatus::Code::Workflow_Server_Incomplete_Information_Provided);
			mState->mUrl = redirectUrl;

			mState->sendGetRequest();
			QCOMPARE(mState->mReply->request().url(), redirectUrl);
		}


		void abortIfNotTcToken()
		{
			QSignalSpy spy(mState.data(), &StateCheckRefreshAddress::fireContinue);
			mAuthContext->setStateApproved();

			QTRY_COMPARE(spy.count(), 1); // clazy:exclude=qstring-allocations
			QVERIFY(mAuthContext->getRefreshUrl().isEmpty());
		}


		void abortIfRefreshAddressIsNotHttps()
		{
			const QByteArray& redirectAddress("http://service.governikus.de/loggedin?7eb39f62");
			const auto& tcToken = createTcToken(redirectAddress);
			mAuthContext->setTcToken(tcToken);

			QSignalSpy spy(mState.data(), &StateCheckRefreshAddress::fireContinue);
			mAuthContext->setStateApproved();

			QTRY_COMPARE(spy.count(), 1); // clazy:exclude=qstring-allocations
			QVERIFY(mAuthContext->getRefreshUrl().isEmpty());
		}


		void isMatchingSameOriginPolicyInDevMode()
		{
			SDK_MODE(false);
			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperOptions(true);

			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperMode(false);
			QVERIFY(!mState->isMatchingSameOriginPolicyInDevMode());

			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperMode(true);
			const QUrl pUrlHttps("https://invalidhost/");
			const QUrl pUrlHttp("http://localhost:12345/test_StateCheckRefreshAddress/");
			const QUrl pSubjectUrl("http://localhost:12345/test_StateCheckRefreshAddress/");

			mState->mUrl = pUrlHttps;
			mState->mSubjectUrl = pSubjectUrl;
			QVERIFY(!mState->isMatchingSameOriginPolicyInDevMode());

			mState->mUrl = pUrlHttp;
			QTest::ignoreMessage(QtCriticalMsg, "SOP-Check: Ignoring scheme and port in developer mode.");
			QTest::ignoreMessage(QtCriticalMsg, "  Origin URL: http://localhost:12345/test_StateCheckRefreshAddress/");
			QTest::ignoreMessage(QtCriticalMsg, "  Refresh URL: http://localhost:12345/test_StateCheckRefreshAddress/");
			QVERIFY(mState->isMatchingSameOriginPolicyInDevMode());
		}


		void determinateSubjectUrl()
		{
			const QUrl tcTokenUrl("http://invalidhost/");
			mAuthContext->setTcTokenUrl(tcTokenUrl);

			QByteArray content = TestFileHelper::readFile(":/paos/DIDAuthenticateEAC1.xml");
			QSharedPointer<DIDAuthenticateEAC1> eac1(static_cast<DIDAuthenticateEAC1*>(DidAuthenticateEac1Parser().parse(content)));

			SDK_MODE(false);
			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperMode(false);
			QTest::ignoreMessage(QtWarningMsg, "No subjectURL/certificate description available, take the TcToken-URL instead");
			QCOMPARE(mState->determineSubjectUrl(), tcTokenUrl);

			mAuthContext->setDidAuthenticateEac1(eac1);
			QCOMPARE(mState->determineSubjectUrl(), QUrl("https://test.governikus-eid.de"));

			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperMode(true);
			QCOMPARE(mState->determineSubjectUrl(), tcTokenUrl);
		}


		void reportCommunicationError()
		{
			mState->mReply = QSharedPointer<MockNetworkReply>::create();
			QSignalSpy spy(mState.data(), &StateCheckRefreshAddress::fireAbort);

			QTest::ignoreMessage(QtCriticalMsg, "Card_Communication_Error | \"An error occurred while communicating with the ID card. Please make sure that your ID card is placed correctly on the card reader and try again.\"");
			mState->reportCommunicationError(GlobalStatus::Code::Card_Communication_Error);
			QCOMPARE(mAuthContext->getStatus().getStatusCode(), GlobalStatus::Code::Card_Communication_Error);
			QCOMPARE(spy.count(), 1);

			mAuthContext->setStatus(GlobalStatus::Code::No_Error);

			QTest::ignoreMessage(QtCriticalMsg, "Network_Other_Error | \"An unknown network error occurred. Check your network connection and try to restart the app.\"");
			mState->reportCommunicationError(GlobalStatus::Code::Network_Other_Error);
			QCOMPARE(mAuthContext->getStatus().getStatusCode(), GlobalStatus::Code::Network_Other_Error);
			QCOMPARE(spy.count(), 2);
		}


		void onNetworkReply_data()
		{
			QTest::addColumn<QNetworkReply::NetworkError>("networkError");
			QTest::addColumn<GlobalStatus::Code>("status");
			QTest::addColumn<int>("statusCode");
			QTest::addColumn<QUrl>("redirectUrl");
			QTest::addColumn<bool>("developerMode");

			QTest::newRow("service unavailable") << QNetworkReply::NetworkError::ServiceUnavailableError << GlobalStatus::Code::Network_ServiceUnavailable << 1 << QUrl("http://governikus.de/") << false;
			QTest::newRow("timeout") << QNetworkReply::NetworkError::TimeoutError << GlobalStatus::Code::Network_TimeOut << 2 << QUrl() << false;
			QTest::newRow("proxy error") << QNetworkReply::NetworkError::ProxyNotFoundError << GlobalStatus::Code::Network_Proxy_Error << 0 << QUrl("test") << false;
			QTest::newRow("ssl error") << QNetworkReply::NetworkError::SslHandshakeFailedError << GlobalStatus::Code::Network_Ssl_Establishment_Error << 1 << QUrl("https://governikus.de/") << false;
			QTest::newRow("other error") << QNetworkReply::NetworkError::OperationCanceledError << GlobalStatus::Code::Network_Other_Error << 2 << QUrl("https://governikus.de/") << false;
			QTest::newRow("no error unexpected status") << QNetworkReply::NetworkError::NoError << GlobalStatus::Code::Workflow_Network_Expected_Redirect << 2 << QUrl("https://governikus.de/") << false;
			QTest::newRow("no error empty url") << QNetworkReply::NetworkError::NoError << GlobalStatus::Code::Workflow_Network_Empty_Redirect_Url << 302 << QUrl() << false;
			QTest::newRow("no error invalid url") << QNetworkReply::NetworkError::NoError << GlobalStatus::Code::Workflow_Network_Malformed_Redirect_Url << 302 << QUrl("://://") << false;
			QTest::newRow("no error http") << QNetworkReply::NetworkError::NoError << GlobalStatus::Code::Workflow_Network_Invalid_Scheme << 302 << QUrl("http://governikus.de/") << false;
			QTest::newRow("no error http developer mode") << QNetworkReply::NetworkError::NoError << GlobalStatus::Code::No_Error << 302 << QUrl("http://governikus.de/") << true;
		}


		void onNetworkReply()
		{
			QFETCH(QNetworkReply::NetworkError, networkError);
			QFETCH(GlobalStatus::Code, status);
			QFETCH(int, statusCode);
			QFETCH(QUrl, redirectUrl);
			QFETCH(bool, developerMode);

			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperMode(developerMode);

			auto reply = QSharedPointer<MockNetworkReply>::create();
			mState->mReply = reply;

			const QByteArray headerName("name");
			const QByteArray value("value");
			reply->setRawHeader(headerName, value);
			reply->setAttribute(QNetworkRequest::HttpStatusCodeAttribute, QVariant(statusCode));
			reply->setAttribute(QNetworkRequest::RedirectionTargetAttribute, QVariant(redirectUrl));
			reply->setError(networkError, QString());

			mAuthContext->setStatus(GlobalStatus::Code::No_Error);
			QTest::ignoreMessage(QtDebugMsg, R"(Header | name: value)");
			mState->onNetworkReply();
			if (!developerMode)
			{
				QCOMPARE(mAuthContext->getStatus().getStatusCode(), status);
			}
		}


		void fetchServerCertificate_DeveloperMode()
		{
			SDK_MODE(false);
			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperMode(true);
			const QUrl url("http://governikus.de/");
			mState->mUrl = url;
			QTest::ignoreMessage(QtWarningMsg, "Refresh URL is http only. Certificate check skipped.");
			mState->fetchServerCertificate();
		}


		void fetchServerCertificate_AlreadyVerified()
		{
			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperMode(false);
			const QUrl url("https://governikus.de/");
			mState->mUrl = url;
			mState->mVerifiedRefreshUrlHosts.insert(0, url);
			QTest::ignoreMessage(QtDebugMsg, "SSL certificate already collected for QUrl(\"https://governikus.de/\")");
			mState->fetchServerCertificate();
		}


		void fetchServerCertificate()
		{
			Env::getSingleton<AppSettings>()->getGeneralSettings().setDeveloperMode(false);
			const QUrl url("https://governikus.de/");
			mState->mUrl = url;
			QTest::ignoreMessage(QtDebugMsg, "Fetch TLS certificate for URL QUrl(\"https://governikus.de/\")");
			mState->fetchServerCertificate();
		}


		void doneSuccess()
		{
			const QUrl url("https://governikus.de/");
			mState->mUrl = url;
			QSignalSpy spy(mState.data(), &StateCheckRefreshAddress::fireContinue);

			QTest::ignoreMessage(QtDebugMsg, "Determined RefreshUrl: QUrl(\"https://governikus.de/\")");
			mState->doneSuccess();
			QCOMPARE(mAuthContext->getRefreshUrl(), url);
		}


};

QTEST_GUILESS_MAIN(test_StateCheckRefreshAddress)
#include "test_StateCheckRefreshAddress.moc"
