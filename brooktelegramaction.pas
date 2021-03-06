unit brooktelegramaction;

{$mode objfpc}{$H+}

interface

uses
  BrookAction, tgtypes, tgsendertypes, sysutils, classes, tgstatlog, eventlog,
  fpjson;

type

  TUserStatus = (usAdmin, usModerator, usDefault, usBanned);

  TWebhookBot = class;

  TRateEvent = procedure (var RateText: String; ReplyMarkup: TReplyMarkup) of object;

  { TWebhookAction }

  TWebhookAction = class(TBrookAction)
  private
    FHelpText: String;
    FLogger: TEventLog;
    FOnCallbackQuery: TCallbackEvent;
    FOnUpdateMessage: TMessageEvent;
    FStartText: String;
    FStatLogger: TtgStatLog;
    FToken: String;
    FBot: TWebhookBot;
    procedure BotStartHandler({%H-}ASender: TObject; const {%H-}ACommand: String;
      {%H-}AMessage: TTelegramMessageObj);
    procedure BotHelpHandler({%H-}ASender: TObject; const {%H-}ACommand: String;
      {%H-}AMessage: TTelegramMessageObj);
    procedure BotSetCommandReply({%H-}ASender: TObject; const ACommand: String;
      AMessage: TTelegramMessageObj);
    procedure BotTerminateHandler({%H-}ASender: TObject; const {%H-}ACommand: String;
      {%H-}AMessage: TTelegramMessageObj);
    procedure SetBot({%H-}AValue: TWebhookBot);
    procedure SetHelpText(AValue: String);
    procedure SetLogger(AValue: TEventLog);
    procedure SetOnCallbackQuery(AValue: TCallbackEvent);
    procedure SetOnUpdateMessage(AValue: TMessageEvent);
    procedure SetStartText(AValue: String);
    procedure SetStatLogger(AValue: TtgStatLog);
    procedure SetToken(AValue: String);
    procedure SendStatLog(ADate: TDate = 0; AReplyMarkup: TReplyMarkup = nil);
    procedure LogMessage({%H-}ASender: TObject; EventType: TEventType; const Msg: String);
  protected
    procedure BotCallbackQuery(ACallback: TCallbackQueryObj); virtual;
    procedure BotMessageHandler(AMessage: TTelegramMessageObj); virtual;
    procedure EditOrSendMessage(const AMessage: String; AParseMode: TParseMode = pmDefault;
      ReplyMarkup: TReplyMarkup = nil; TryEdit: Boolean = False);
    function IsSimpleUser: Boolean;
    function IsBanned: Boolean;
    procedure SaveFeedback(AFrom: TTelegramUserObj; AMessage: String); virtual; abstract;
  public
    constructor Create; override;
    destructor Destroy; override;
    procedure Post; override;
    property Token: String read FToken write SetToken;
    property OnCallbackQuery: TCallbackEvent read FOnCallbackQuery write SetOnCallbackQuery;
    property OnUpdateMessage: TMessageEvent read FOnUpdateMessage write SetOnUpdateMessage;
    property StartText: String read FStartText write SetStartText; // Text for /start command reply
    property HelpText: String read FHelpText write SetHelpText;  // Text for /help command reply
    property StatLogger: TtgStatLog read FStatLogger write SetStatLogger;
    property Logger: TEventLog read FLogger write SetLogger;
    property Bot: TWebhookBot read FBot write SetBot;
  end;

  { TWebhookBot }
  TWebhookBot = class(TTelegramSender)
  private
    FBrookAction: TWebhookAction;
    FFeedbackText: String;
    FFeedbackThanks: String;
    FOnRate: TRateEvent;
    FUserPermissions: TStringList;
    procedure DoCallbackQueryStat(ACallbackQuery: TCallbackQueryObj; SendFile: Boolean = False);
    procedure DoGetStat(ADate: TDate = 0; SendFile: Boolean = false);
    procedure DoStat(const SDate: String; SendFile: Boolean = false);
    function GetUserStatus(ID: Int64): TUserStatus;
    procedure SetBrookAction(AValue: TWebhookAction);
    procedure SetOnRate(AValue: TRateEvent);
    procedure SetUserStatus(ID: Int64; AValue: TUserStatus);
    procedure TlgrmFeedback({%H-}ASender: TObject; const {%H-}ACommand: String;
      {%H-}AMessage: TTelegramMessageObj);
    procedure TlgrmRate({%H-}ASender: TObject; const {%H-}ACommand: String;
      {%H-}AMessage: TTelegramMessageObj);
    procedure TlgrmStatHandler({%H-}ASender: TObject;
      const {%H-}ACommand: String; AMessage: TTelegramMessageObj);
    procedure TlgrmStatFHandler({%H-}ASender: TObject;
      const {%H-}ACommand: String; AMessage: TTelegramMessageObj);
    procedure LangTranslate(const {%H-}ALang: String);
    procedure SendStatInlineKeyboard(SendFile: Boolean = False);
    procedure StatLog(const AMessage: String; UpdateType: TUpdateType);
  protected
    function CreateInlineKeyboardRate: TJSONArray;
    function CreateInlineKeyboardStat(SendFile: Boolean): TJSONArray;
    procedure DoReceiveMessageUpdate(AMessage: TTelegramMessageObj); override;
    procedure DoReceiveCallbackQuery(ACallback: TCallbackQueryObj); override;
    procedure DoReceiveChannelPost(AChannelPost: TTelegramMessageObj); override;
    procedure DoReceiveChosenInlineResult(
      AChosenInlineResult: TTelegramChosenInlineResultObj); override;
    procedure DoReceiveInlineQuery(AnInlineQuery: TTelegramInlineQueryObj); override;
    procedure DebugMessage(const Msg: String); override;
    procedure InfoMessage(const Msg: String); override;
    procedure ErrorMessage(const Msg: String); override;
    property BrookAction: TWebhookAction read FBrookAction write SetBrookAction;
    function IsBanned(ChatID: Int64): Boolean; override;       
    function IsSimpleUser(ChatID: Int64): Boolean; override;
    procedure SetLanguage(const ALang: String); override;
  public
    constructor Create(const AToken: String; AWebhookAction: TWebhookAction);
    destructor Destroy; override;
    procedure LoadUserStatusValues(AStrings: TStrings);
    property FeedbackText: String read FFeedbackText write FFeedbackText;
    property FeedbackThanks: String read FFeedbackThanks write FFeedbackThanks;
    property UserStatus [ID: Int64]: TUserStatus read GetUserStatus write SetUserStatus;
    property OnRate: TRateEvent read FOnRate write SetOnRate;
  end;

function ExtractArgPart(const ASource, ACommand: String): String;
function FormatStatRec(const S: String): String;

implementation
{ Please define ni18n (No i18n) for excluding translate unit from uses and exclude i18n support }
uses jsonparser, BrookHttpConsts, strutils, BrookApplication, jsonscanner{$IFNDEF ni18n},
  Translations{$ENDIF}, tgutils;

// Please use i18n for localization *** Пожалуйста, используйте i18n для локализации
resourcestring
  str_FeedbackThanks='Thanks! %s Your message will be considered!'; // Спасибо, %s! Ваш сообщение будет обязательно рассмотрено!;
  str_FeedbackText='Send us a wish, recommendation or bug report';  // Отправьте разработчику бота пожелание, рекомендацию, информацию об ошибке
  str_TxtRplyIsScsChngd='Text reply for command is succesfully changed!'; // Текст сообщения для команды успешно изменен
  str_BtApIsClsd='Bot app is closed';  // Приложение закрыто
  str_SttstcsNtFnd='Statistics for this date not found'; // Статистика не найдено за указанный день
  str_ErrFldTLdSttstcsFl='Error: failed to load statistics file';
  str_EntrDtInFrmt='Please enter the date in format: dd-mm-yyyy';
  str_SttstcsFr='Statistics for ';
  str_SlctSttstcs_line1='Select statistics by pressing the button. In addition, the available commands:';
  str_SlctSttstcs_line2='/stat <i>day</i> - the last records for a specified <i>date</i>, ';
  str_SlctSttstcs_line3= '/statf <i>date</i> - statistics file for the <i>date</i>,';
  str_SlctSttstcs_line4='where <i>date</i> is <i>today</i> or <i>yesterday</i> or in format <i>dd-mm-yyyy</i>';
  str_Today='Today';
  str_Yesterday='Yesterday';
  str_Rate='Rate';
  str_RateText='Please leave feedback on "Storebot" if you like our bot!';


const
  StatDateFormat = 'dd-mm-yyyy';
  UserStatusChars: array [TUserStatus] of AnsiChar = ('a', 'm', 'b', '_');
  cmd_Start = '/start';
  cmd_Help = '/help';
  cmd_Stat = '/stat';
  cmd_StatF = '/statf';
  cmd_Terminate = '/terminate';
  cmd_Feedback = '/feedback';
  cmd_SetStart = '/setstart';
  cmd_SetHelp = '/sethelp';
  cmd_Rate = '/rate';
  s_Today = 'today';
  s_Yesterday = 'yesterday';
  s_GetStat='GetStat';
  s_File='File';
  s_StoreBotRate='https://telegram.me/storebot?start=';

function AnsiCharToUserStatus(const StatusChar: String): TUserStatus;
var
  a: AnsiChar;
begin
  if StatusChar=EmptyStr then
    a:=UserStatusChars[usDefault]
  else
    a:=PAnsiChar(StatusChar)[0];
  case a of
    'a': Result:=usAdmin;
    'm': Result:=usModerator;
    'b': Result:=usBanned;
  else
    Result:=usDefault;
  end;
end;

function ExtractArgPart(const ASource, ACommand: String): String;
begin
  Result:=Trim(RightStr(ASource, Length(ASource)-Length(ACommand)));
end;

function FormatStatRec(const S: String): String;
var
  Ss: TStringList;
  l: Integer;
begin
  Ss:=TStringList.Create;
  l:=ExtractStrings([';'], [' '], PChar(S), Ss, True);
  if l<>8 then
    Result:='Stat line parser error'
  else
    Result:=Ss[0]+'; '+'['+Ss[1]+'](tg://user?id='+Ss[1]+') '+
      MarkdownEscape(Ss[2]+' {'+Ss[3]+' '+Ss[4]+'}')+ ' '+
      MarkdownEscape(Ss[5])+' <'+MarkdownEscape(Ss[6])+'> '+MarkdownEscape(Ss[7]);
  Ss.Free;
end;

{ TWebhookBot }

procedure TWebhookBot.SetBrookAction(AValue: TWebhookAction);
begin
  if FBrookAction=AValue then Exit;
  FBrookAction:=AValue;
end;

procedure TWebhookBot.SetOnRate(AValue: TRateEvent);
begin
  if FOnRate=AValue then Exit;
  FOnRate:=AValue;
end;

procedure TWebhookBot.DoCallbackQueryStat(ACallbackQuery: TCallbackQueryObj;
  SendFile: Boolean);
begin
  DoStat(ExtractDelimited(2, ACallbackQuery.Data, [' ']), SendFile);
  { After the user presses a callback button, Telegram clients will display a progress bar until
you call answerCallbackQuery. It is, therefore, necessary to react by calling answerCallbackQuery
even if no notification to the user is needed }
  RequestWhenAnswer:=False;
  answerCallbackQuery(ACallbackQuery.ID);
end;

procedure TWebhookBot.DoGetStat(ADate: TDate = 0; SendFile: Boolean = false);
var
  StatFile: TStringList;
  Msg, SDate: String;
  AFileName: String;
  i: Integer;
  ReplyMarkup: TReplyMarkup;
begin
  if CurrentIsSimpleUser then
    Exit;
  ReplyMarkup:=TReplyMarkup.Create;
  try
    ReplyMarkup.InlineKeyBoard:=CreateInlineKeyboardStat(SendFile);
    if SendFile then
      FBrookAction.SendStatLog(ADate, ReplyMarkup)
    else begin
      StatFile:=TStringList.Create;
      try
        AFileName:=FBrookAction.StatLogger.GetFileNameFromDate(ADate);
        RequestWhenAnswer:=False;
        try
          if FileExists(AFileName) then
          begin
            DateTimeToString(SDate, 'dd-mm-yyyy', ADate);
            StatFile.LoadFromFile(AFileName);
            Msg:='*Statistics for '+SDate+'*'+LineEnding;
            for i:=StatFile.Count-1 downto StatFile.Count-20 do
            begin
              if i<0 then
                Break;
              Msg+=FormatStatRec(StatFile[i])+LineEnding;
            end;
            editMessageText(Msg, pmMarkdown, True, ReplyMarkup);
          end
          else
            editMessageText(str_SttstcsNtFnd, pmDefault, True, ReplyMarkup);
        except
          editMessageText(str_ErrFldTLdSttstcsFl, pmDefault, True, ReplyMarkup);
        end;
      finally
        StatFile.Free;
      end;
    end;
  finally
    ReplyMarkup.Free;
  end;
end;

procedure TWebhookBot.DoStat(const SDate: String; SendFile: Boolean = false);
var
  FDate: TDate;
  S: String;
begin
  if not Assigned(FBrookAction.StatLogger) then
    Exit;
  S:=Trim(SDate);
  if (S=s_Today) or (S=EmptyStr) then
    FDate:=Date
  else
    if S=s_Yesterday then
      FDate:=Date-1
    else
      if not TryStrToDate(S, FDate, StatDateFormat) then
      begin
        RequestWhenAnswer:=True;
        sendMessage(str_EntrDtInFrmt);
        Exit;
      end;
  DoGetStat(FDate, SendFile);
end;

function TWebhookBot.GetUserStatus(ID: Int64): TUserStatus;
begin
  Result:=AnsiCharToUserStatus(FUserPermissions.Values[IntToStr(ID)]);
end;

procedure TWebhookBot.SetUserStatus(ID: Int64; AValue: TUserStatus);
var
  i: Integer;
begin
  if AValue=usDefault then
  begin
    i:= FUserPermissions.IndexOf(IntToStr(ID));
    if i >-1 then
      FUserPermissions.Delete(i)
    else
      Exit;
  end;
  FUserPermissions.Values[IntToStr(ID)]:=UserStatusChars[AValue];
end;

procedure TWebhookBot.TlgrmFeedback(ASender: TObject; const ACommand: String;
  AMessage: TTelegramMessageObj);
var
  ReplyMarkup: TReplyMarkup;
begin
  ReplyMarkup:=TReplyMarkup.Create;
  try
    ReplyMarkup.ForceReply:=True;
    sendMessage(FFeedbackText, pmMarkdown, True, ReplyMarkup);
  finally
    ReplyMarkup.Free;
  end;
end;

procedure TWebhookBot.TlgrmRate(ASender: TObject; const ACommand: String;
  AMessage: TTelegramMessageObj);
var
  ReplyMarkup: TReplyMarkup;
  ATxt: String;
begin
  ReplyMarkup:=TReplyMarkup.Create;
  try
    { You must assign BotUsername before Create inline KeyboardRate for forming rate url for your bot
      except if FUsername already assinged (getMe or callbackquery before is called, for example) }
    ReplyMarkup.InlineKeyBoard:=CreateInlineKeyboardRate;
    RequestWhenAnswer:=True;
    ATxt:=str_RateText;
    if Assigned(FOnRate) then
      FOnRate(ATxt, ReplyMarkup);
    sendMessage(ATxt, pmMarkdown, True, ReplyMarkup);
  finally
    ReplyMarkup.Free;
  end;
end;

procedure TWebhookBot.TlgrmStatHandler(ASender: TObject;
  const ACommand: String; AMessage: TTelegramMessageObj);
var
  S: String;
begin
  if CurrentIsSimpleUser then
    Exit;
  RequestWhenAnswer:=True;
  S:=ExtractDelimited(2, AMessage.Text, [' ']);
  if S<>EmptyStr then
    DoStat(S)
  else
    SendStatInlineKeyboard();
end;

procedure TWebhookBot.TlgrmStatFHandler(ASender: TObject;
  const ACommand: String; AMessage: TTelegramMessageObj);
var
  S: String;
begin
  if CurrentIsSimpleUser then
    Exit;
  RequestWhenAnswer:=True;
  S:=ExtractDelimited(2, AMessage.Text, [' ']);
  if S<>EmptyStr then
     DoStat(S, True)
  else
    SendStatInlineKeyboard(True);
end;

{ Please define ni18n (No i18n) for excluding translate unit from uses and exclude i18n support }
procedure TWebhookBot.LangTranslate(const ALang: String);{$IFNDEF ni18n}
var
  L, F: String;  {$ENDIF}
begin{$IFNDEF ni18n}
  if Length(ALang)>2 then
    L:=LeftStr(ALang, 2)
  else
    L:=ALang;
  F:='languages'+PathDelim+ApplicationName+'.%s.po';
  TranslateResourceStrings(F, L, '');{$ENDIF}
end;

procedure TWebhookBot.SendStatInlineKeyboard(SendFile: Boolean);
var
  ReplyMarkup: TReplyMarkup;
begin
  ReplyMarkup:=TReplyMarkup.Create;
  try
    ReplyMarkup.InlineKeyBoard:=CreateInlineKeyboardStat(SendFile);
    RequestWhenAnswer:=True;
    sendMessage(str_SlctSttstcs_line1+LineEnding+str_SlctSttstcs_line2+LineEnding+
      str_SlctSttstcs_line3+LineEnding+str_SlctSttstcs_line4, pmHTML, True, ReplyMarkup);
  finally
    ReplyMarkup.Free;
  end;
end;

procedure TWebhookBot.StatLog(const AMessage: String; UpdateType: TUpdateType);
var
  EscMsg: String;
begin
  EscMsg:=AMessage;
  if Length(EscMsg)>150 then
    SetLength(EscMsg, 150);
  if CurrentIsSimpleUser then
    if Assigned(CurrentUser)then
      FBrookAction.StatLogger.Log([IntToStr(CurrentChatId), '@'+CurrentUser.Username, CurrentUser.First_name, CurrentUser.Last_name,
        CurrentUser.Language_code, UpdateTypeAliases[UpdateType], '"'+StringToJSONString(EscMsg)+'"'])
    else
      FBrookAction.StatLogger.Log(['', '', '', '', '', UpdateTypeAliases[UpdateType], '"'+EscMsg+'"'])
end;

function TWebhookBot.CreateInlineKeyboardRate: TJSONArray;
var
  btns: TInlineKeyboardButtons;
  btn: TInlineKeyboardButton;
begin
  btns:=TInlineKeyboardButtons.Create;
  btn:=TInlineKeyboardButton.Create(str_Rate);
  btn.url:=s_StoreBotRate+BotUsername;
  btns.Add(btn);
  Result:=TJSONArray.Create;
  Result.Add(btns);
end;

function TWebhookBot.CreateInlineKeyboardStat(SendFile: Boolean): TJSONArray;
var
  btns: TInlineKeyboardButtons;
  FileApp: String;
begin
  if SendFile then
    FileApp:='File'
  else
    FileApp:='';
  btns:=TInlineKeyboardButtons.Create;
  btns.AddButtons([str_Today+' 🔃', s_GetStat+FileApp+' '+s_Today,
    str_Yesterday, s_GetStat+FileApp+' '+s_Yesterday]);
  Result:=TJSONArray.Create;
  Result.Add(btns);
end;

constructor TWebhookBot.Create(const AToken: String;
  AWebhookAction: TWebhookAction);
begin
  inherited Create(AToken);
  FBrookAction:=AWebhookAction;
  FUserPermissions:=TStringList.Create;
  FUserPermissions.Sorted:=True;
  FUserPermissions.Duplicates:=dupIgnore;
  FFeedbackThanks:=str_FeedbackThanks;
  FFeedbackText:=str_FeedbackText;
  CommandHandlers[cmd_Feedback]:=@TlgrmFeedback;
  CommandHandlers[cmd_Rate]:=@TlgrmRate;
  CommandHandlers[cmd_Stat]:=@TlgrmStatHandler;
  CommandHandlers[cmd_StatF]:=@TlgrmStatFHandler;
end;

destructor TWebhookBot.Destroy;
begin
  FUserPermissions.Free;
  inherited Destroy;
end;

procedure TWebhookBot.DoReceiveMessageUpdate(AMessage: TTelegramMessageObj);
begin
  inherited DoReceiveMessageUpdate(AMessage);
  if Assigned(AMessage.ReplyToMessage) then
  begin
    if Assigned(AMessage.ReplyToMessage.From) then
      if SameText(AMessage.ReplyToMessage.From.Username, BotUsername) then
      begin
        sendMessage(Format(FFeedbackThanks, [AMessage.From.First_name]));
        With AMessage do
          FBrookAction.SaveFeedback(From, Text);
      end;
    Exit;
  end;
  StatLog(AMessage.Text, utMessage);
  FBrookAction.BotMessageHandler(AMessage);
end;

procedure TWebhookBot.DoReceiveCallbackQuery(ACallback: TCallbackQueryObj);
var
  AHandled: Boolean;
begin
  AHandled:=False;
  inherited DoReceiveCallbackQuery(ACallback);
  if not CurrentIsSimpleUser then
  begin
    if AnsiStartsStr(s_GetStat+' ', ACallback.Data) then
    begin
      AHandled:=True;
      DoCallbackQueryStat(ACallback);
    end;
    if AnsiStartsStr(s_GetStat+s_File+' ', ACallback.Data) then
    begin
      AHandled:=True;
      DoCallbackQueryStat(ACallback, True);
    end;
  end
  else
    StatLog(ACallback.Data, utCallbackQuery);
  if not AHandled then
    FBrookAction.BotCallbackQuery(ACallback);
end;

procedure TWebhookBot.DoReceiveChannelPost(AChannelPost: TTelegramMessageObj);
begin
  inherited DoReceiveChannelPost(AChannelPost);
  StatLog(AChannelPost.Text, utChannelPost);
end;

procedure TWebhookBot.DoReceiveChosenInlineResult(
  AChosenInlineResult: TTelegramChosenInlineResultObj);
begin
  inherited DoReceiveChosenInlineResult(AChosenInlineResult);
  StatLog(AChosenInlineResult.Query, utChosenInlineResult);
end;

procedure TWebhookBot.DoReceiveInlineQuery(
  AnInlineQuery: TTelegramInlineQueryObj);
begin
  inherited DoReceiveInlineQuery(AnInlineQuery);
  StatLog(AnInlineQuery.Query, utInlineQuery);
end;

procedure TWebhookBot.DebugMessage(const Msg: String);
begin
  inherited DebugMessage(Msg);
  FBrookAction.LogMessage(Self, etDebug, Msg);
end;

procedure TWebhookBot.InfoMessage(const Msg: String);
begin
  inherited InfoMessage(Msg);                 
  FBrookAction.LogMessage(Self, etInfo, Msg);
end;

procedure TWebhookBot.ErrorMessage(const Msg: String);
begin
  inherited ErrorMessage(Msg);
  FBrookAction.LogMessage(Self, etError, Msg);
end;

function TWebhookBot.IsBanned(ChatID: Int64): Boolean;
begin
  Result:=FUserPermissions.Values[IntToStr(ChatID)]='b'
end;

function TWebhookBot.IsSimpleUser(ChatID: Int64): Boolean;
begin
  Result:=(FUserPermissions.Values[IntToStr(ChatID)]<>'a') and
    (FUserPermissions.Values[IntToStr(ChatID)]<>'m');
end;

procedure TWebhookBot.SetLanguage(const ALang: String);
begin
  inherited SetLanguage(ALang);
  LangTranslate(ALang);
end;

procedure TWebhookBot.LoadUserStatusValues(AStrings: TStrings);
begin
  FUserPermissions.AddStrings(AStrings);
end;

  { TWebhookAction }

procedure TWebhookAction.SetToken(AValue: String);
begin
  if FToken=AValue then Exit;
  FToken:=AValue;
  if Assigned(FBot) then
    FBot.Token:=FToken;
end;

procedure TWebhookAction.SetStartText(AValue: String);
begin
  if FStartText=AValue then Exit;
  FStartText:=AValue;
end;

procedure TWebhookAction.SetStatLogger(AValue: TtgStatLog);
begin
  if FStatLogger=AValue then Exit;
  FStatLogger:=AValue;
end;

procedure TWebhookAction.SetOnCallbackQuery(AValue: TCallbackEvent);
begin
  if FOnCallbackQuery=AValue then Exit;
  FOnCallbackQuery:=AValue;
end;

procedure TWebhookAction.SetOnUpdateMessage(AValue: TMessageEvent);
begin
  if FOnUpdateMessage=AValue then Exit;
  FOnUpdateMessage:=AValue;
end;

procedure TWebhookAction.BotStartHandler(ASender: TObject;
  const ACommand: String; AMessage: TTelegramMessageObj);
begin
  Bot.RequestWhenAnswer:=True;
  Bot.sendMessage(FStartText, pmMarkdown);
end;

procedure TWebhookAction.BotHelpHandler(ASender: TObject;
  const ACommand: String; AMessage: TTelegramMessageObj);
begin
  Bot.RequestWhenAnswer:=True;
  Bot.sendMessage(FHelpText, pmMarkdown);
end;
{ Caution! You must save this values in db or in configuration file! }
procedure TWebhookAction.BotSetCommandReply(ASender: TObject;
  const ACommand: String; AMessage: TTelegramMessageObj);
var
  S: String;
begin
  if IsSimpleUser then
    Exit;
  S:=ExtractArgPart(AMessage.Text, ACommand);
  if ACommand=cmd_SetStart then
    StartText:=S
  else
    if ACommand=cmd_SetHelp then
      HelpText:=S;
  Bot.sendMessage(str_TxtRplyIsScsChngd);
end;

procedure TWebhookAction.BotTerminateHandler(ASender: TObject;
  const ACommand: String; AMessage: TTelegramMessageObj);
begin
  if IsSimpleUser then
    Exit;
  FBot.RequestWhenAnswer:=True;
  FBot.sendMessage(str_BtApIsClsd);
  BrookApp.Terminate;
end;

procedure TWebhookAction.SetBot(AValue: TWebhookBot);
begin
// todo Does It need a code here? Can it be so?
end;

procedure TWebhookAction.SetHelpText(AValue: String);
begin
  if FHelpText=AValue then Exit;
  FHelpText:=AValue;
end;

procedure TWebhookAction.SetLogger(AValue: TEventLog);
begin
  if FLogger=AValue then Exit;
  FLogger:=AValue;
end;

function TWebhookAction.IsSimpleUser: Boolean;
begin
  Result:=FBot.CurrentIsSimpleUser;
end;

function TWebhookAction.IsBanned: Boolean;
begin
  Result:=Bot.CurrentIsBanned;
end;

procedure TWebhookAction.BotCallbackQuery(ACallback: TCallbackQueryObj);
begin
  if Assigned(FOnCallbackQuery) then
    FOnCallbackQuery(Self, ACallback);
end;

procedure TWebhookAction.BotMessageHandler(AMessage: TTelegramMessageObj);
begin
  if Assigned(FOnUpdateMessage) then
    FOnUpdateMessage(Self, AMessage);
end;

procedure TWebhookAction.SendStatLog(ADate: TDate = 0; AReplyMarkup: TReplyMarkup = nil);
var
  AFileName: String;
begin
  if ADate=0 then
    ADate:=sysutils.Date;
  AFileName:=StatLogger.GetFileNameFromDate(ADate);
  if FileExists(AFileName) then
  begin
    FBot.RequestWhenAnswer:=False;
    FBot.sendDocumentByFileName(Bot.CurrentChatId, AFileName, str_SttstcsFr+DateToStr(ADate));
  end
  else
  begin
    FBot.RequestWhenAnswer:=True;
    EditOrSendMessage(str_SttstcsNtFnd, pmDefault, AReplyMarkup, True);
  end;
end;

procedure TWebhookAction.LogMessage(ASender: TObject; EventType: TEventType; const Msg: String);
begin
  if Assigned(FLogger) then
    Logger.Log(EventType, Msg);
end;

{ Sometimes, if the message is sent to the result of the CallBack call,
it is desirable not to create a new message and edit the message from which the call came }
procedure TWebhookAction.EditOrSendMessage(const AMessage: String;
  AParseMode: TParseMode; ReplyMarkup: TReplyMarkup; TryEdit: Boolean);
begin
  if not TryEdit or (Bot.CurrentUpdate.UpdateType<>utCallbackQuery) then
    Bot.sendMessage(AMessage, AParseMode, True, ReplyMarkup)
  else
    Bot.editMessageText(AMessage, AParseMode, True, ReplyMarkup);
end;

constructor TWebhookAction.Create;
begin
  inherited Create;
  FStatLogger:=TtgStatLog.Create(nil);
  FStatLogger.Active:=False;
  FStatLogger.TimeStampFormat:='hh:nn:ss';
  FBot:=TWebhookBot.Create(FToken, Self);
  FBot.CommandHandlers[cmd_Start]:=    @BotStartHandler;
  FBot.CommandHandlers[cmd_Help]:=     @BotHelpHandler;
  FBot.CommandHandlers[cmd_Terminate]:=@BotTerminateHandler;
  FBot.CommandHandlers[cmd_SetStart]:= @BotSetCommandReply;
  FBot.CommandHandlers[cmd_SetHelp]:=  @BotSetCommandReply;
end;

destructor TWebhookAction.Destroy;
begin
  FBot.Free;
  FStatLogger.Free;
  inherited Destroy;
end;

procedure TWebhookAction.Post;
var
  Msg: String;
  lParser: TJSONParser;
  AnUpdate: TTelegramUpdateObj;
begin
  Msg:={$IFNDEF bf30}HttpRequest{$ELSE}TheRequest{$ENDIF}.Content;
  LogMessage(Self, etDebug, 'Recieve the update (Webhook): '+Msg);
  if Msg<>EmptyStr then
  begin
    lParser := TJSONParser.Create(Msg, DefaultOptions);
    try
      try
        AnUpdate :=
          TTelegramUpdateObj.CreateFromJSONObject(lParser.Parse as TJSONObject) as TTelegramUpdateObj;
      except
      end;
    finally
      lParser.Free;
    end;
    if Assigned(AnUpdate) then
    begin
      Bot.DoReceiveUpdate(AnUpdate);
      {$IFNDEF bf30}HttpResponse{$ELSE}TheResponse{$ENDIF}.ContentType:=BROOK_HTTP_CONTENT_TYPE_APP_JSON;
      Write(FBot.RequestBody);
    end;
  end;
end;

end.
