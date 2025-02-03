unit uMain;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Variants,

  Vcl.Controls,
  Vcl.Dialogs,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  ShellAPI,

  Winapi.Messages,
  Winapi.Windows,
  Vcl.StdCtrls;

type
  TfrmMain = class(TForm)
    pnlClientMain: TPanel;
    pnlBottom: TPanel;
    btnCreateJWT: TButton;
    btnSendJWT: TButton;
    btnOpenNet: TButton;
    pnlMmo: TPanel;
    pnlMmoClient: TPanel;
    pnlMmoLeft: TPanel;
    pnlMmoTop: TPanel;
    pnlLeftMmo: TPanel;
    pnlTop: TPanel;
    pnlTopBottom: TPanel;
    lblTitleJWT: TLabel;
    pnlToppLeft: TPanel;
    lblName: TLabel;
    lblCompany: TLabel;
    edtLocation: TEdit;
    edtMachine: TEdit;
    pnlTopRight: TPanel;
    pnlRightTop: TPanel;
    lblNewJWT: TLabel;
    mmoNewJWT: TMemo;
    pnlRightBottom: TPanel;
    lblKeysJWT: TLabel;
    mmoKeys: TMemo;
    pnlTopTop: TPanel;
    lblTitleServer: TLabel;
    lblPort: TLabel;
    edtPort: TEdit;
    pnlToppBottom: TPanel;
    btnRunServer: TButton;
    btnStopServer: TButton;
    pnlTitleTop: TPanel;
    pnlTitleTLeft: TPanel;
    procedure FormActivate(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure btnRunServerClick(Sender: TObject);
    procedure btnOpenNetClick(Sender: TObject);
    procedure btnStopServerClick(Sender: TObject);
    procedure btnSendJWTClick(Sender: TObject);
    procedure btnCreateJWTClick(Sender: TObject);
  private
    function BasicAuth(const AUsername, APassword: string): Boolean;
    procedure StandardTHorse(Port: Integer);
    { Private declarations }
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;

implementation

uses
  Horse,
  Horse.JWT,
  System.JSON,
  Horse.Jhonson,
  JOSE.Core.JWT,
  JOSE.Core.JWK,
  System.DateUtils,
  JOSE.Core.Builder,
  Horse.BasicAuthentication;

{$R *.dfm}

procedure TfrmMain.FormActivate(Sender: TObject);
begin
  mmoKeys.Clear;
  mmoNewJWT.Clear;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
//
end;

function TfrmMain.BasicAuth(const AUsername, APassword: String): Boolean;
begin
  Result := AUsername.Equals('SOS Solucoes') and APassword.Equals('Fabio Ghizoni');
end;

procedure TfrmMain.StandardTHorse(Port: Integer);
begin

    THorse
      .Use(Jhonson)
      .Use(HorseBasicAuthentication(BasicAuth, THorseBasicAuthenticationConfig
        .New.SkipRoutes('/Private/Login')))
      .Use(HorseJWT('MySecretKey',
        THorseJWTConfig.New.SkipRoutes('').SkipRoutes('/')));

  THorse.Listen(THorse.Port,
  procedure
  begin

    Caption := Format('Sistema Principal - Status(Horse): Rodando em %d', [THorse.Port]);

    THorse.Post('/',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LKey1, LKey2, LCompactToken: String;
      LToken: TJWT; LKey: TJWK;
      LJsonObj: TJSONObject;
    begin

      LKey1 := Req.Headers['Machine'];
      LKey2 := Req.Headers['Location'];

      if not (Trim(LKey1) <> 'Note Dell') and
         not (Trim(LKey2) <> 'Manoel Ribas') then
      begin

        LToken := TJWT.Create;
        LKey := TJWK.Create('MySecretKey');

        LToken.Claims.Issuer := LKey1;
        LToken.Claims.Subject := LKey2;
        LToken.Claims.IssuedAt := Now;
        LToken.Claims.Expiration := IncHour(Now + 1);

        LCompactToken := TJOSE.SHA256CompactToken('MySecretKey', LToken);
        LToken := TJOSE.Verify(LKey, LCompactToken);

        if LToken.Verified then
        begin
          mmoNewJWT.Clear;
          LJsonObj := TJSONObject.Create;
          LJsonObj.AddPair('Token', LCompactToken);
          Res.Send(LJsonObj.ToJSON).ContentType('application/json');
          mmoNewJWT.Text := LJsonObj.ToJSON;
        end
        else
          Res.Send('Erro na Validação do Token');

      end
      else
        Res.Send('Chaves inválidas');

    end);

    THorse.Post('/Private/Login',
    procedure(Req: THorseRequest; Res: THorseResponse)
    var
      LJsonObj: TJSONObject;
      LCompactToken: String;
      LToken: TJWT;
      LKey: TJWK;
    begin
      LJsonObj := TJSONObject.Create;
      LKey := TJWK.Create('MySecretKey');
      LCompactToken := Req.Headers['Authorization'];
      LCompactToken := LCompactToken.Substring(7);
      LToken := TJOSE.Verify(LKey, LCompactToken);
      LJsonObj.AddPair('Issuer', LToken.Claims.Issuer);
      LJsonObj.AddPair('Subject', LToken.Claims.Subject);
      LJsonObj.AddPair('IssuedAt', LToken.Claims.IssuedAt);
      LJsonObj.AddPair('Expiration', LToken.Claims.Expiration);
      Res.Send(LJsonObj.ToJSON);
    end);

  end);

end;

procedure TfrmMain.btnRunServerClick(Sender: TObject);
var
  Port: Integer;
begin
  Port := StrToInt(edtPort.Text);
  if not THorse.IsRunning and (Port > 0) then
  begin
    THorse.Port := Port;
    StandardTHorse(THorse.Port);
  end;
end;

procedure TfrmMain.btnStopServerClick(Sender: TObject);
begin
  if THorse.IsRunning then
  begin
    Caption := 'Sistema Principal - Status(Horse): Parando horse...';
    THorse.StopListen;
    Sleep(500);
  end
  else
    Caption := 'Sistema Principal - Status(Horse): Parado';
end;

procedure TfrmMain.btnSendJWTClick(Sender: TObject);
begin
//
end;

procedure TfrmMain.btnCreateJWTClick(Sender: TObject);
begin
//
end;

procedure TfrmMain.btnOpenNetClick(Sender: TObject);
var
  Url: String;
begin
  if THorse.IsRunning then
  begin
    Url := Format('http://localhost:%d', [THorse.Port]);
    ShellExecute(0, nil, PChar(Url), nil, nil, SW_SHOWNOACTIVATE);
  end;
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
//
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
//
end;

end.
