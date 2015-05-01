use inc::Module::Install;

if (!can_run('hmperl')) {
    die "You must have an 'hmperl' in your \$PATH. Maybe run: sudo ln -vis `which perl` /usr/local/bin/hmperl\n";
}

name('BTDT');
version('0.01');
requires('Business::CreditCard');
requires('Business::Hours' => '0.08');
requires('Business::OnlinePayment');
requires('Business::OnlinePayment::AuthorizeNet' => 3.21);
requires('Business::OnlinePayment::AuthorizeNet::AIM::ErrorCodes');
requires('Calendar::Simple');
requires('CGI::Simple::Cookie');
requires('Chatbot::Eliza');
requires('Class::Accessor');
requires('Class::Accessor::Fast');
requires('Class::Data::Inheritable');
requires('Color::Calc');
requires('Compress::Zlib');
requires('Coro'); # Coro::Debug Coro::Socket Coro::State
requires('Crypt::OpenSSL::RSA');
requires('Data::ICal' => '0.07');  # Data::ICal::Entry::Todo Data::ICal::Entry::Event
requires('Data::Page');
requires('Data::Plist'); # Data::Plist::BinaryReader Data::Plist::BinaryWriter Data::Plist::Foundation::LibraryToDo
requires('Date::Extract' => '0.02');
requires('Date::ICal');
requires('Date::Manip');
requires('DateTime' => '0.38');
requires('DateTime::Duration');
requires('DateTime::Format::ISO8601');
requires('DateTime::Format::Mail');
requires('DateTime::Format::Natural' => 0.67);
requires('DateTime::TimeZone');
requires('DBD::Pg');
requires('Digest::HMAC_SHA1');
requires('Email::Address');
requires('Email::Folder');
requires('Email::LocalDelivery' => 0.214);
requires('Email::MessageID');
requires('Email::MIME' => 1.862); # Email::MIME::ContentType Email::MIME::Header
requires('Email::MIME::Attachment::Stripper' => 1.315);
requires('Email::MIME::Creator');
requires('Email::Reply' => '1.200');
requires('Email::Send');
requires('Email::Send::IO');
requires('Email::Simple::Creator');
requires('Email::Simple'); # Email::Simple::Header
requires('Encode::IMAPUTF7');
requires('File::Find::Rule');
requires('GD');
requires('Geography::States');
requires('HTML::Entities');
requires('HTML::FormatText::WithLinks');
requires('HTML::Mason' => '1.37');           # HTML::Mason::CGIHandler
requires('HTML::Scrubber');
requires('HTML::TagCloud' => '0.31');
requires('HTML::TokeParser');
requires('HTTP::Cookies');         # Hiveminder::Client 
requires('HTTP::Date');
requires('IO::All');               # Used by Email::Send::IO
requires('Jifty'      => 0.60728);
requires('Jifty::DBI' => 0.68);    # Jifty::DBI::SchemaGenerator DBD::SQLite
requires('Jifty::Plugin::AccessLog' => 1.1);
requires('Jifty::Plugin::Chart' => 1.01);
requires('Jifty::Plugin::Monitoring');
requires('Jifty::Plugin::OAuth' => 0.02);
requires('Jifty::Plugin::Quota');
requires('List::MoreUtils');
requires('LWP::Protocol::http');
requires('LWP::Simple' => 5.827);
requires('LWP::UserAgent');
requires('Module::CoreList');
requires('Module::Refresh');
requires('Module::ScanDeps'); #Module::ScanDeps::DataFeed
requires('Net::IMAP::Server' => 1.27); # Net::IMAP::Server::Connection Net::IMAP::Server::Command
requires('Net::IMAP::Simple' => 1.1914);
requires('Net::IMAP::Simple::SSL');
requires('Net::Jabber');
requires('Net::OAuth::Request' => '0.05'); # Net::OAuth::Request::RequestTokenRequest Net::OAuth::Request::AccessTokenRequest Net::OAuth::Request::ProtectedResourceRequest
requires('Net::OSCAR' => 1.928);
requires('Net::Twitter::Lite' => '0.08003');
requires('Number::RecordLocator'); #Module::ScanDeps::DataFeed
requires('Plack');
requires('Plack::Request');
requires('Proc::ProcessTable');
requires('Regexp::Common');
requires('Regexp::Common::Email::Address');
requires('Regexp::Common::URI::RFC2396');
requires('Scalar::Defer');
requires('String::Koremutake');
requires('Term::ReadKey');
requires('Test::Deep');
requires('Test::Dependencies');
requires('Test::HTML::Lint');
requires('Test::LongString');
requires('Test::MockTime');
requires('Test::WWW::Mechanize');
requires('Test::WWW::Selenium' => '1.0.2');
requires('Text::Autoformat');
requires('Text::FixEOL');
requires('Text::Markdown' => '1.0.19');
requires('Text::Password::Pronounceable');
requires('Text::Quoted');
requires('Text::Tags' => '0.03');            # Text::Tags::Parser
requires('Time::Duration');
requires('Time::ParseDate');
requires('UNIVERSAL::require');
requires('URI');
requires('URI::Escape' => 3.30);
requires('version');
requires('WWW::Mechanize' => 1.50);
requires('XML::Atom');             # XML::Atom::Entry XML::Atom::Feed
requires('XML::Writer'); 
requires('YAML');

feature 'todo.pl testing only' => -default => 0,
    'App::Todo'                => 0,
    ;

feature 'Starman' => -default => 0,
    'Plack::Runner' => 0,
    ;

feature 'Jabber server' => -default => 0,
    'DJabberd' => 0, # DJabberd::Log
    ;

makemaker_args( MAN3PODS => {} ); # Don't write any man files
auto_install();
&WriteAll;
